# 08. Kiến trúc `billing-service` (`com.animallocket.billing`)

`billing-service` (`:8106`, PostgreSQL `billing_db`) quản lý toàn bộ nghiệp vụ thương mại hoá theo nguyên tắc **Fail-Closed**:
- Danh mục 8 sản phẩm (`Product`: `SUBSCRIPTION`, `CONSUMABLE`, `PACK`), lịch sử giao dịch (`Purchase`), thuê bao Pro (`Subscription`), ví vật phẩm (`WalletBalance`) và sổ cái bất biến (`LedgerEntry`).
- Tách bạch `PurchaseFlow` (xác thực biên lai qua mạng với Apple/Google **ngoài** transaction DB) và `BillingService.grant()` (ghi DB + cộng ví + phát sự kiện Outbox **trong một transaction ngắn**).
- Xác thực chữ ký JWS `ES256` + chuỗi chứng chỉ PKIX X.509 Apple Root CA G3 (`AppleStoreGateway`, `AppleJwsVerifier`) và gọi Google Play Developer API v3 kèm lần chuỗi `linkedPurchaseToken` (`GoogleStoreGateway`, `HttpGooglePlayClient`).
- Xử lý thông báo gia hạn/hết hạn/hoàn tiền từ Apple ASSN v2 và Google RTDN (`WebhookController`, `AppleWebhookHandler`, `GoogleWebhookHandler`, `WebhookProcessor`) cùng tiến trình nền hạ cấp thuê bao quá hạn (`BillingMaintenance`).

---

## 1. Class Diagram (`billing-service`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Domain Entities (com.animallocket.billing.domain)
    %% ==========================================
    class Product {
        <<@Entity products>>
        -String sku
        -Type type
        -String item
        -int quantity
        -boolean active
    }
    note for Product "Loại sản phẩm (Type):\n- SUBSCRIPTION (Pro tháng/năm)\n- CONSUMABLE (BOOST, PRIORITY_INVITE)\n- PACK (Gói thú mở khoá vĩnh viễn)."

    class Purchase {
        <<@Entity purchases>>
        -Long id
        -Store store
        -String storeTransactionId
        -String originalTransactionId
        -String publicId
        -String sku
        -Status status
        -Instant createdAt
    }
    note for Purchase "Khoá duy nhất (store, storeTransactionId) chống dùng lại biên lai.\nStatus: GRANTED | REFUNDED."

    class Subscription {
        <<@Entity subscriptions>>
        -Long id
        -String publicId
        -String sku
        -Store store
        -String originalTransactionId
        -Status status
        -Instant expiresAt
        -Instant updatedAt
    }
    note for Subscription "Khoá duy nhất (store, originalTransactionId).\nStatus: ACTIVE | EXPIRED."

    class WalletBalance {
        <<@Entity wallet_balances>>
        -String publicId
        -String item
        -int balance
    }

    class LedgerEntry {
        <<@Entity wallet_ledger>>
        -Long id
        -String publicId
        -String item
        -int delta
        -String reason
        -String ref
        -Instant createdAt
    }
    note for LedgerEntry "Sổ cái bất biến có khoá duy nhất (reason, ref, item)\nđảm bảo không bao giờ cộng hoặc trừ ví 2 lần cho cùng một sự kiện."

    class WebhookEvent {
        <<@Entity webhook_events>>
        -String id
        -String store
        -String type
        -Instant receivedAt
    }

    %% ==========================================
    %% Store Verification Gateways (com.animallocket.billing.store)
    %% ==========================================
    class StoreGateway {
        <<interface>>
        +store() Store
        +verify(String sku, String token) VerifiedPurchase
    }

    class StoreRouter {
        <<@Component>>
        -Map~Store, StoreGateway~ gateways
        +verify(Store store, String sku, String token) VerifiedPurchase
    }
    note for StoreRouter "Định tuyến tới cổng Store tương ứng.\nNếu Store chưa cấu hình -> ném StoreException(UNAVAILABLE) (Fail-closed)."

    class StoreCaller {
        -CircuitBreakerRegistry breakers
        -RetryRegistry retries
        +call(String name, Call~T~ fn) T
    }
    note for StoreCaller "Bọc lời gọi HTTP tới Apple/Google bằng Resilience4j Retry + CircuitBreaker.\nChỉ retry/tính lỗi mạch khi gặp StoreException(UNAVAILABLE)."

    class AppleJwsVerifier {
        -List~X509Certificate~ roots
        -Set~TrustAnchor~ anchors
        -boolean requireAppleOid
        -Clock clock
        +verify(String jws) JsonNode
    }
    note for AppleJwsVerifier "Xác thực JWS ES256 của Apple:\n1. Kiểm tra alg == ES256\n2. Xác thực chuỗi chứng chỉ x5c theo PKIX tới Apple Root CA\n3. Kiểm tra OID 1.2.840.113635.100.6.11.1 trên leaf cert\n4. Kiểm tra chữ ký ECDSA P1363."

    class AppleStoreGateway {
        -AppleProperties props
        -AppleJwsVerifier verifier
        -RestClient http
        -StoreCaller caller
        -PrivateKey apiKey
        +store() Store
        +verify(String sku, String token) VerifiedPurchase
    }

    class GooglePlayClient {
        <<interface>>
        +getSubscription(String packageName, String purchaseToken) SubscriptionInfo
        +getProduct(String packageName, String sku, String purchaseToken) ProductInfo
        +acknowledgeSubscription(String packageName, String sku, String purchaseToken) void
        +acknowledgeProduct(String packageName, String sku, String purchaseToken) void
    }

    class HttpGooglePlayClient {
        -GoogleProperties props
        -RestClient http
        -StoreCaller caller
        -AccessTokenProvider tokens
        +getSubscription(...) SubscriptionInfo
        +getProduct(...) ProductInfo
        +acknowledgeSubscription(...) void
        +acknowledgeProduct(...) void
    }

    class GoogleSubscriptionResolver {
        <<interface>>
        +resolveSubscription(String purchaseToken) Resolved
    }

    class GoogleStoreGateway {
        -GoogleProperties props
        -GooglePlayClient client
        -ProductRepository products
        +store() Store
        +verify(String sku, String token) VerifiedPurchase
        +resolveSubscription(String purchaseToken) Resolved
    }
    note for GoogleStoreGateway "Lần ngược chuỗi linkedPurchaseToken tối đa 5 bước\nvà băm SHA-256 token gốc để tạo originalTransactionId cố định."

    class DevStoreGateway {
        <<@Component>>
        +store() Store
        +verify(String sku, String token) VerifiedPurchase
    }

    %% ==========================================
    %% Services & Web/Webhook Layer
    %% ==========================================
    class WalletService {
        <<@Service>>
        -WalletBalanceRepository balances
        -LedgerRepository ledger
        +credit(String publicId, String item, int qty, String reason, String ref) boolean
        +debit(String publicId, String item, int n, String reason, String ref) boolean
        +balances(String publicId) Map~String, Integer~
        +wipe(String publicId) void
    }

    class PurchaseFlow {
        <<@Service>>
        -ProductRepository products
        -StoreRouter stores
        -BillingService billing
        +verifyAndGrant(String me, VerifyRequest req) MeResponse
    }
    note for PurchaseFlow "Cố ý KHÔNG đánh dấu @Transactional:\nGọi mạng tới Apple/Google trước, xong mới mở transaction ngắn ở BillingService.grant()."

    class BillingService {
        <<@Service>>
        -ProductRepository products
        -PurchaseRepository purchases
        -SubscriptionRepository subscriptions
        -WebhookEventRepository webhooks
        -WalletService wallet
        -OutboxService outbox
        +catalog() List~ProductView~
        +me(String publicId) MeResponse
        +grant(String me, Store store, Product product, VerifiedPurchase vp) MeResponse
        ~refreshEntitlement(String publicId) void
        +consume(String publicId, String item) void
        +firstTimeWebhook(String id, Store store, String type) boolean
        +onSubscriptionUpdated(Store store, String origTxId, Instant expiresAt) boolean
        +onSubscriptionEnded(Store store, String origTxId) boolean
        +onRefund(Store store, String txId) boolean
        +expireDue(Duration grace) int
        +onUserDeleted(String publicId) void
    }

    class BillingMaintenance {
        <<@Component>>
        -BillingService billing
        -IdempotencyService idempotency
        -Duration grace
        +expire() void
        +onUserEvent(String json) void
    }

    class BillingController {
        <<@RestController>>
        -BillingService billing
        -PurchaseFlow flow
        -WalletService wallet
        +products() List~ProductView~
        +me(String me) MeResponse
        +verify(String me, VerifyRequest req) MeResponse
        +consume(ConsumeRequest req) void
        +wallet(String publicId) Map~String, Integer~
    }

    class WebhookController {
        <<@RestController /webhooks>>
        -AppleWebhookHandler apple
        -GoogleWebhookHandler google
        +apple(AppleBody body) Map~String, String~
        +google(String authorization, JsonNode body) Map~String, String~
    }

    class WebhookProcessor {
        <<@Component>>
        -BillingService billing
        +process(String dedupeId, Store store, String type, Runnable action) boolean
    }

    class AppleWebhookHandler {
        <<@Component>>
        -AppleProperties props
        -AppleJwsVerifier verifier
        -WebhookProcessor processor
        -BillingService billing
        +handle(String signedPayload) String
    }

    class GoogleWebhookHandler {
        <<@Component>>
        -GoogleProperties props
        -GooglePushAuth auth
        -GoogleSubscriptionResolver resolver
        -WebhookProcessor processor
        -BillingService billing
        +handle(String authorizationHeader, JsonNode pushBody) String
    }

    StoreGateway <|.. AppleStoreGateway : implements
    StoreGateway <|.. GoogleStoreGateway : implements
    StoreGateway <|.. DevStoreGateway : implements
    GoogleSubscriptionResolver <|.. GoogleStoreGateway : implements
    GooglePlayClient <|.. HttpGooglePlayClient : implements
    StoreRouter --> StoreGateway : routes
    AppleStoreGateway --> AppleJwsVerifier : verifies JWS
    AppleStoreGateway --> StoreCaller : wraps HTTP
    GoogleStoreGateway --> GooglePlayClient : calls Play API
    HttpGooglePlayClient --> StoreCaller : wraps HTTP
    BillingController --> PurchaseFlow : verify
    BillingController --> BillingService : catalog/me/consume
    PurchaseFlow --> StoreRouter : verifies receipt outside tx
    PurchaseFlow --> BillingService : grants inside tx
    BillingService --> WalletService : credits/debits
    WebhookController --> AppleWebhookHandler : delegates
    WebhookController --> GoogleWebhookHandler : delegates
    AppleWebhookHandler --> WebhookProcessor : runs in tx
    GoogleWebhookHandler --> WebhookProcessor : runs in tx
    WebhookProcessor --> BillingService : updates/ends/refunds
    BillingMaintenance --> BillingService : expires & cleans
```

---

## 2. Sequence Diagrams theo Từng Class (`billing-service`)

### 2.1 Class `BillingController`, `PurchaseFlow`, `BillingService` & `WalletService` — Xác thực Biên lai & Cấp Quyền lợi

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobile Client
    participant BC as BillingController
    participant PF as PurchaseFlow (Non-Transactional)
    participant SR as StoreRouter / StoreGateway
    participant BS as BillingService (@Transactional)
    participant WS as WalletService (MANDATORY Tx)
    participant Repo as PostgreSQL Repos (Purchase / Sub / Wallet / Ledger)
    participant Outbox as OutboxService

    Client->>BC: POST /api/v1/billing/purchases/verify ({store, sku, token})
    BC->>PF: verifyAndGrant(me, req)
    PF->>Repo: products.findById(sku).filter(isActive) (Nếu không có -> 400 UNKNOWN_PRODUCT)
    Note over PF,SR: Bước 1: Gọi mạng hỏi Store NGOÀI DB Transaction (không giữ kết nối DB)
    PF->>SR: verify(store, sku, token)
    alt Biên lai giả mạo / không hợp lệ (StoreException.Kind.INVALID)
        SR-->>PF: throw StoreException(INVALID)
        PF-->>Client: 400 Bad Request (INVALID_RECEIPT)
    else Store tạm lỗi / Chưa cấu hình (StoreException.Kind.UNAVAILABLE)
        SR-->>PF: throw StoreException(UNAVAILABLE)
        PF-->>Client: 503 Service Unavailable (STORE_UNAVAILABLE - Client giữ giao dịch để thử lại)
    else Xác thực thành công
        SR-->>PF: VerifiedPurchase(txId, origTxId, sku, purchasedAt, expiresAt, revoked)
        PF->>PF: Kiểm tra vp.sku == req.sku (400 SKU_MISMATCH) & !vp.revoked (400 RECEIPT_REVOKED)
        Note over PF,Outbox: Bước 2: Mở Transaction ngắn để ghi DB + cộng ví + ghi Outbox
        PF->>BS: grant(me, store, product, vp)
        BS->>Repo: purchases.findByStoreAndStoreTransactionId(store, vp.txId)
        alt Đã tồn tại giao dịch này
            alt Thuộc về người dùng khác (existing.publicId != me)
                BS-->>Client: 409 Conflict (RECEIPT_ALREADY_USED)
            else Thuộc về chính người gọi (Gọi lại Idempotent)
                BS-->>Client: 200 OK (me(me))
            end
        else Giao dịch mới
            BS->>Repo: purchases.save(new Purchase(store, txId, origTxId, me, sku))
            alt product.type == SUBSCRIPTION
                BS->>Repo: Tìm hoặc tạo Subscription theo (store, origTxId) (Nếu gắn user khác -> 409)
                BS->>Repo: Cập nhật sku, expiresAt, status=ACTIVE & subscriptions.save()
                BS->>Outbox: publish(BILLING, SUBSCRIPTION_ACTIVATED, me, {me, "PRO", expiresAt})
            else product.type == CONSUMABLE (BOOST / PRIORITY_INVITE)
                BS->>WS: credit(me, item, quantity, "PURCHASE", "purchase:" + purchaseId)
                WS->>Repo: Kiểm tra existsByReasonAndRefAndItem -> Lưu LedgerEntry -> UPDATE wallet_balances + qty
                BS->>Outbox: publish(BILLING, CONSUMABLE_GRANTED, me, {me, item, quantity})
            else product.type == PACK
                BS->>Outbox: publish(BILLING, CONSUMABLE_GRANTED, me, {me, "ANIMAL_PACK:" + item, 1})
            end
            BS-->>PF: MeResponse(plan, planExpiresAt, wallet)
            PF-->>BC: MeResponse
            BC-->>Client: 200 OK (Client nhận 200 xong mới gọi completePurchase với Store!)
        end
    end
```

---

### 2.2 Class `AppleStoreGateway` & `AppleJwsVerifier` — Xác thực Giao dịch App Store Server API & Chuỗi Chứng chỉ PKIX

```mermaid
sequenceDiagram
    autonumber
    participant SR as StoreRouter
    participant ASG as AppleStoreGateway
    participant Caller as StoreCaller (Retry + CircuitBreaker)
    participant Apple as App Store Server API
    participant Verifier as AppleJwsVerifier

    SR->>ASG: verify(sku, transactionId)
    ASG->>ASG: Kiểm tra transactionId chỉ gồm chữ số ^[0-9]{1,30}$ & đã nạp khoá .p8
    ASG->>Caller: call("store-apple", () -> getTransaction(baseUrl, transactionId))
    Caller->>ASG: Ký apiJwt() ES256 (sống 5 phút) bằng khoá .p8
    ASG->>Apple: GET /inApps/v1/transactions/{transactionId} (Authorization: Bearer <apiJwt>)
    alt 404 ở Production và bật allowSandboxFallback
        Apple-->>ASG: 404 Not Found
        ASG->>Apple: Thử lại trên Sandbox URL
    end
    Apple-->>ASG: 200 OK {"signedTransactionInfo": "<JWS>"}
    ASG->>Verifier: verify(signedTransactionInfo)
    Verifier->>Verifier: 1. Kiểm tra header alg == "ES256"
    Verifier->>Verifier: 2. Giải mã chuỗi chứng chỉ x5c (leaf -> intermediate -> Apple Root CA)
    Verifier->>Verifier: 3. CertPathValidator.validate(certPath, PKIXParameters(appleRootAnchors))
    Verifier->>Verifier: 4. Kiểm tra leaf cert mang Apple OID (1.2.840.113635.100.6.11.1)
    Verifier->>Verifier: 5. Xác thực chữ ký SHA256withECDSAinP1363Format trên header.payload
    Verifier-->>ASG: JsonNode transactionPayload
    ASG->>ASG: Đối chiếu bundleId, productId == sku, transactionId, environment
    ASG-->>SR: VerifiedPurchase(txId, origTxId, sku, purchaseDate, expiresDate, revoked)
```

---

### 2.3 Class `GoogleStoreGateway` & `HttpGooglePlayClient` — Xác thực Giao dịch Google Play API v3 & Chuỗi `linkedPurchaseToken`

```mermaid
sequenceDiagram
    autonumber
    participant SR as StoreRouter
    participant GSG as GoogleStoreGateway
    participant Repo as ProductRepository
    participant Play as HttpGooglePlayClient (qua StoreCaller)
    participant Google as Google Play Developer API v3

    SR->>GSG: verify(sku, purchaseToken)
    GSG->>Repo: products.findById(sku)
    alt Sản phẩm là SUBSCRIPTION
        GSG->>GSG: resolveSubscription(purchaseToken)
        loop Tối đa 5 bước lần ngược linkedPurchaseToken
            GSG->>Play: getSubscription(packageName, currentToken)
            Play->>Google: GET /androidpublisher/v3/.../subscriptionsv2/tokens/{token}
            Google-->>Play: SubscriptionInfo(state, lineItems, linkedPurchaseToken, acknowledged)
            Play-->>GSG: SubscriptionInfo
            Note over GSG: Nếu có linkedPurchaseToken mới -> tiếp tục bước lặp để tìm rootToken
        end
        GSG->>GSG: originalTransactionId = SHA256_Hex(rootToken) (64 ký tự cố định)
        opt serverAcknowledge == true && !acknowledged
            GSG->>Play: acknowledgeSubscription(packageName, sku, purchaseToken)
        end
        GSG-->>SR: VerifiedPurchase(latestOrderId, originalTransactionId, sku, null, expiryTime, revoked)
    else Sản phẩm là CONSUMABLE hoặc PACK (Mua 1 lần)
        GSG->>Play: getProduct(packageName, sku, purchaseToken)
        Play->>Google: GET /androidpublisher/v3/.../purchases/products/{sku}/tokens/{token}
        Google-->>Play: ProductInfo(purchaseState, consumptionState, acknowledgementState, orderId)
        Play-->>GSG: ProductInfo
        opt serverAcknowledge == true && acknowledgementState == 0
            GSG->>Play: acknowledgeProduct(packageName, sku, purchaseToken)
        end
        GSG-->>SR: VerifiedPurchase(orderId, orderId, sku, purchaseTime, null, canceledOrRefunded)
    end
```

---

### 2.4 Class `WebhookController`, `AppleWebhookHandler`, `GoogleWebhookHandler` & `WebhookProcessor` — Xử lý Webhook từ Store

```mermaid
sequenceDiagram
    autonumber
    actor Store as Apple ASSN v2 / Google Pub/Sub RTDN
    participant WC as WebhookController
    participant AWH as AppleWebhookHandler
    participant GWH as GoogleWebhookHandler
    participant Auth as OidcGooglePushAuth / AppleJwsVerifier
    participant WP as WebhookProcessor (@Transactional)
    participant BS as BillingService

    alt Webhook từ Apple (POST /webhooks/apple)
        Store->>WC: POST /webhooks/apple {"signedPayload": "<JWS>"}
        WC->>AWH: handle(signedPayload)
        AWH->>Auth: verifier.verify(outerJws) & verifier.verify(innerSignedTransactionInfo)
        AWH->>AWH: Kiểm tra notificationUUID, bundleId, phân loại RENEW / END / REFUND
        AWH->>WP: process("apple:" + notificationUUID, APPLE, notificationType, action)
        WP->>BS: firstTimeWebhook(dedupeId, APPLE, type)
        opt Chưa xử lý webhook này (firstTime == true)
            WP->>BS: onSubscriptionUpdated(...) / onSubscriptionEnded(...) / onRefund(...)
            BS->>BS: Cập nhật DB + phát SUBSCRIPTION_ACTIVATED / SUBSCRIPTION_EXPIRED qua Outbox
        end
        AWH-->>WC: "PROCESSED" / "DUPLICATE"
        WC-->>Store: 200 OK
    else Webhook từ Google (POST /webhooks/google)
        Store->>WC: POST /webhooks/google (Authorization: Bearer <OIDC>, body Pub/Sub)
        WC->>GWH: handle(authorizationHeader, body)
        GWH->>Auth: authenticate(authorizationHeader) (Kiểm tra JWT Google, aud, email_verified)
        GWH->>GWH: Giải mã Base64 message.data -> lấy purchaseToken & notificationType
        GWH->>GWH: resolver.resolveSubscription(purchaseToken) (Hỏi lại Google Play trạng thái thật)
        GWH->>WP: process("google:" + messageId, GOOGLE, type, action)
        WP->>BS: firstTimeWebhook(dedupeId, GOOGLE, type)
        opt Chưa xử lý webhook này
            WP->>BS: onSubscriptionUpdated(...) / onSubscriptionEnded(...) / onRefund(...)
        end
        GWH-->>WC: "PROCESSED" / "DUPLICATE"
        WC-->>Store: 200 OK
    end
```

