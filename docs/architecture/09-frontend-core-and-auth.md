# 09. Kiến trúc Flutter Frontend — Tầng Core, Xác thực OIDC & Thiết bị Push (`mobile/lib/core`, `features/auth`, `features/devices`, `features/shell`)

Tài liệu này mô tả thiết kế lớp (Class Diagram có comment) và sơ đồ tuần tự (Sequence Diagram theo từng class) cho tầng nền tảng của ứng dụng di động Flutter (`mobile/lib/`):
1. **`core/config`, `core/network`, `core/cache`, `core/models`, `core/router`, `core/widgets`**: Cấu hình `--dart-define`, Dio HTTP client (`ApiClient` tự động đính kèm Bearer JWT, xoá `X-Public-Id`, tự làm mới token khi gặp `401` và thử lại `GET` khi `503`), lưu trữ token bảo mật (`SecureTokenStore`), bộ nhớ đệm ngoại tuyến SQLite (`CacheDatabase`), định tuyến bảo vệ theo trạng thái xác thực (`appRouterProvider`).
2. **`core/auth` & `features/auth`**: Luồng đăng nhập OIDC PKCE qua Keycloak (`SessionManager`), quản lý trạng thái phiên & hồ sơ (`AuthController`), và 3 màn hình Onboarding (`SignInScreen`, `BirthConsentScreen`, `RevealScreen`).
3. **`features/devices` & `features/shell`**: Tự động đăng ký/huỷ đăng ký FCM token (`PushService`, `LiveDevicesRepository`) và khung điều hướng 4 tab (`AppShell`).

---

## 1. Class Diagram (`core/`, `auth`, `devices`, `shell`)

```mermaid
classDiagram
    direction TB

    %% ==========================================
    %% Core Config, Storage & Cache
    %% ==========================================
    class AppConfig {
        +String apiBaseUrl
        +String wsUrl
        +String keycloakIssuer
        +String keycloakClientId
        +String oauthRedirectUrl
        +bool enablePush
        +bool enableBilling
        +bool backendTests
        +String apiV1BaseUrl
        +fromEnvironment()$ AppConfig
    }
    note for AppConfig "Đọc toàn bộ biến môi trường từ --dart-define.\nKhông bao giờ hardcode khoá bí mật trong mã nguồn."

    class BackendModeController {
        <<Notifier~BackendMode~>>
        +build() BackendMode
        +useDemo() void
        +useLive() void
    }
    note for BackendModeController "Cho phép chuyển đổi linh hoạt giữa chế độ Demo (in-memory) và Live (gọi API thật)."

    class TokenBundle {
        +String accessToken
        +String refreshToken
        +String idToken
        +DateTime expiresAt
        +bool isExpired
        +bool shouldRefresh
    }
    note for TokenBundle "shouldRefresh = true khi thời hạn còn dưới 45 giây."

    class TokenStore {
        <<interface>>
        +read() Future~TokenBundle?~
        +write(TokenBundle bundle) Future~void~
        +clear() Future~void~
    }

    class SecureTokenStore {
        -FlutterSecureStorage _storage
        +read() Future~TokenBundle?~
        +write(TokenBundle bundle) Future~void~
        +clear() Future~void~
    }
    note for SecureTokenStore "Lưu trữ OIDC token an toàn trong Keychain (iOS) / Keystore (Android)."

    class CacheDatabase {
        -Database? _db
        +write(String key, Object? value) Future~void~
        +read(String key) Future~Object?~
        +clear() Future~void~
        +close() Future~void~
    }
    note for CacheDatabase "Kho đệm SQLite (sqflite) lưu trang đầu Feed, danh sách hội thoại và tin nhắn\nđể mở app ngoại tuyến mượt mà; xoá sạch khi đăng xuất."

    %% ==========================================
    %% Network & Error Handling
    %% ==========================================
    class ApiProblem {
        +int? status
        +String code
        +Duration? retryAfter
        +bool isNetworkFailure
        +String userMessage
        +fromDioException(DioException err)$ ApiProblem
    }
    note for ApiProblem "Ánh xạ lỗi RFC 7807 sang thông báo tiếng Việt dựa trên mã code ổn định,\nkhông bao giờ hiển thị chuỗi detail thô từ server."

    class ApiClient {
        -Dio _dio
        -SessionManager _sessionManager
        +Dio raw
        -_onRequest(RequestOptions options, RequestInterceptorHandler handler) Future~void~
        -_onError(DioException err, ErrorInterceptorHandler handler) Future~void~
        +get(String path, Map queryParameters) Future~Response~
        +post(String path, Object? data) Future~Response~
        +put(String path, Object? data) Future~Response~
        +patch(String path, Object? data) Future~Response~
        +delete(String path) Future~Response~
    }
    note for ApiClient "Interceptor Dio:\n1. Xoá X-Public-Id, gắn Authorization: Bearer <JWT>.\n2. Gặp 401 -> gọi SessionManager.refresh() và retry đúng 1 lần.\n3. Gặp 503 hoặc lỗi mạng trên GET -> retry tối đa 2 lần (backoff 400ms, 1200ms)."

    %% ==========================================
    %% Auth & Session Management
    %% ==========================================
    class SessionManager {
        -AppConfig _config
        -TokenStore _tokenStore
        -FlutterAppAuth _appAuth
        -Future~TokenBundle?~? _refreshInFlight
        +hasSession() Future~bool~
        +accessToken() Future~String?~
        +signIn() Future~TokenBundle~
        +refresh() Future~TokenBundle?~
        +signOut() Future~void~
    }
    note for SessionManager "Thực hiện OIDC Authorization Code + PKCE với Keycloak.\nGộp các yêu cầu refresh đồng thời qua biến _refreshInFlight."

    class AuthState {
        +AuthStatus status
        +MeProfile? profile
        +String? errorMessage
    }

    class AuthController {
        <<Notifier~AuthState~>>
        +build() AuthState
        +bootstrap() Future~void~
        +signIn() Future~void~
        +enterDemo() Future~void~
        -_resolveProfile() Future~void~
        +registerProfile(DateTime birthDate, String? alias) Future~MeProfile~
        +finishRegistration(MeProfile profile) void
        +refreshProfile() Future~void~
        +signOut() Future~void~
    }
    note for AuthController "Điều phối trạng thái xác thực (checking -> unauthenticated | needsProfile | ready).\nKhi nhận 403 PROFILE_REQUIRED từ /users/me sẽ chuyển sang needsProfile."

    %% ==========================================
    %% Screens & Push Service
    %% ==========================================
    class SignInScreen {
        <<ConsumerWidget>>
        +build(BuildContext context, WidgetRef ref) Widget
    }

    class BirthConsentScreen {
        <<ConsumerStatefulWidget>>
        +createState() State
    }

    class RevealScreen {
        <<ConsumerStatefulWidget>>
        +DateTime birthDate
        +createState() State
    }

    class DevicesRepository {
        <<interface>>
        +register(String token, String platform) Future~void~
        +unregister(String token) Future~void~
    }

    class LiveDevicesRepository {
        -ApiClient _client
        +register(String token, String platform) Future~void~
        +unregister(String token) Future~void~
    }

    class PushService {
        -AppConfig _config
        -DevicesRepository _devices
        -String? _currentToken
        +initialize() Future~void~
        +unregister() Future~void~
    }

    class AppShell {
        <<ConsumerWidget>>
        +StatefulNavigationShell navigationShell
        +build(BuildContext context, WidgetRef ref) Widget
    }

    TokenStore <|.. SecureTokenStore : implements
    DevicesRepository <|.. LiveDevicesRepository : implements
    SessionManager --> TokenStore : reads/writes tokens
    SessionManager --> AppConfig : reads OIDC config
    ApiClient --> SessionManager : gets & refreshes JWT
    ApiClient ..> ApiProblem : maps DioException
    AuthController --> SessionManager : signIn/signOut
    AuthController --> CacheDatabase : clears on signOut
    AuthController --> PushService : unregisters on signOut
    PushService --> DevicesRepository : registers/unregisters FCM token
    LiveDevicesRepository --> ApiClient : PUT/DELETE /devices
    SignInScreen --> AuthController : watches & calls signIn
    BirthConsentScreen --> RevealScreen : navigates with birthDate
    RevealScreen --> AuthController : registerProfile & finishRegistration
```

---

## 2. Sequence Diagrams theo Từng Class (`core/`, `auth`, `devices`)

### 2.1 Class `SessionManager`, `AuthController`, `SignInScreen`, `BirthConsentScreen` & `RevealScreen` — Luồng Đăng nhập OIDC PKCE & Khởi tạo Hồ sơ

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant SignIn as SignInScreen
    participant AC as AuthController
    participant SM as SessionManager (FlutterAppAuth)
    participant Store as SecureTokenStore
    participant KC as Keycloak OIDC Server
    participant UR as LiveUserRepository (ApiClient)
    participant Birth as BirthConsentScreen
    participant Reveal as RevealScreen

    User->>SignIn: Nhấn "Đăng nhập"
    SignIn->>AC: signIn()
    AC->>SM: signIn()
    SM->>KC: authorizeAndExchangeCode (OIDC + PKCE, scopes: openid, profile)
    KC-->>SM: AuthorizationTokenResponse(accessToken, refreshToken, idToken, expiresAt)
    SM->>Store: write(TokenBundle)
    SM-->>AC: TokenBundle
    AC->>AC: _resolveProfile()
    AC->>UR: me() (GET /api/v1/users/me)
    alt Người dùng đã có hồ sơ (200 OK)
        UR-->>AC: MeProfile
        AC->>AC: state = AuthState.ready(profile) -> GoRouter tự điều hướng sang /camera
    else Người dùng mới chưa có hồ sơ (403 PROFILE_REQUIRED hoặc 404)
        UR-->>AC: throw ApiProblem(code: "PROFILE_REQUIRED")
        AC->>AC: state = AuthState.needsProfile() -> GoRouter tự điều hướng sang /birth-consent
        User->>Birth: Chọn ngày sinh + Tích đồng ý điều khoản & nhấn Tiếp tục
        Birth->>Reveal: context.go('/reveal?birthDate=yyyy-MM-dd')
        User->>Reveal: Nhập biệt danh (hoặc để trống tự sinh) & nhấn Mở nhân vật
        Reveal->>AC: registerProfile(birthDate, alias)
        AC->>UR: register(birthDate, alias) (POST /api/v1/users/register)
        UR-->>AC: MeProfile (kèm leadAnimal vừa được gán)
        AC-->>Reveal: MeProfile (Hiển thị thẻ con vật chủ đạo)
        User->>Reveal: Nhấn "Bắt đầu dùng Animal Locket"
        Reveal->>AC: finishRegistration(profile)
        AC->>AC: state = AuthState.ready(profile) -> GoRouter điều hướng vào /camera
    end
```

---

### 2.2 Class `ApiClient` & `SessionManager` — Tự động Làm mới Token khi `401` & Thử lại khi `503`

```mermaid
sequenceDiagram
    autonumber
    participant Repo as Feature Repository
    participant Api as ApiClient (Dio Interceptor)
    participant SM as SessionManager
    participant Store as SecureTokenStore
    participant GW as API Gateway (:8080)

    Repo->>Api: get('/feed') / post(...)
    Api->>Api: _onRequest: options.headers.remove('X-Public-Id')
    Api->>SM: accessToken()
    SM->>Store: read()
    opt bundle.shouldRefresh (còn < 45 giây)
        SM->>SM: refresh() (Gộp chung qua _refreshInFlight nếu nhiều request cùng gọi)
        SM->>Store: write(newBundle)
    end
    SM-->>Api: validAccessToken
    Api->>GW: HTTP Request (Authorization: Bearer <validAccessToken>)
    alt Phản hồi 401 Unauthorized (và chưa retry _retried401)
        GW-->>Api: 401 Unauthorized
        Api->>SM: refresh()
        alt Refresh thành công
            SM-->>Api: newBundle
            Api->>GW: Thực hiện lại request với Bearer token mới (_retried401 = true)
            GW-->>Api: 200 OK
            Api-->>Repo: Response
        else Refresh thất bại
            SM->>Store: clear()
            Api-->>Repo: throw ApiProblem(status: 401, code: "UNAUTHORIZED")
        end
    else Phản hồi 503 hoặc lỗi kết nối trên phương thức GET (attempt < 2)
        GW-->>Api: 503 Service Unavailable / Connection Timeout
        Api->>Api: Đợi backoff (400ms ở lần 1, 1200ms ở lần 2)
        Api->>GW: Thử lại GET request
        GW-->>Api: Response
        Api-->>Repo: Response
    else Lỗi nghiệp vụ RFC 7807 (400 / 402 / 403 / 404 / 409 / 429)
        GW-->>Api: ProblemDetail JSON {status, code, detail}
        Api->>Api: ApiProblem.fromDioException(err) (Đọc trường code và header Retry-After)
        Api-->>Repo: throw ApiProblem
    end
```

---

### 2.3 Class `PushService`, `LiveDevicesRepository` & `AuthController` — Đăng ký FCM Token & Dọn dẹp khi Đăng xuất

```mermaid
sequenceDiagram
    autonumber
    participant App as AnimalLocketApp (pushBootstrapProvider)
    participant PS as PushService
    participant FCM as FirebaseMessaging
    participant DR as LiveDevicesRepository
    participant AC as AuthController
    participant Cache as CacheDatabase

    Note over App,DR: 1. Khi AuthStatus chuyển sang ready -> Tự động đăng ký FCM Token
    App->>PS: initialize() (nếu config.enablePush == true)
    PS->>FCM: requestPermission()
    alt Người dùng cấp quyền thông báo (authorized / provisional)
        PS->>FCM: getToken()
        FCM-->>PS: fcmToken
        PS->>DR: register(token: fcmToken, platform: 'ANDROID' | 'IOS')
        DR->>DR: PUT /api/v1/devices {token, platform}
        FCM-->>PS: onTokenRefresh.listen(...) -> Tự động gọi lại DR.register(newToken)
    end

    Note over AC,Cache: 2. Khi người dùng Đăng xuất (signOut)
    AC->>PS: unregister()
    opt Đang có _currentToken
        PS->>DR: unregister(_currentToken) (DELETE /api/v1/devices/{token})
    end
    AC->>AC: sessionManager.signOut() (Xoá SecureTokenStore)
    AC->>Cache: clear() (Xoá toàn bộ dữ liệu đệm SQLite)
    AC->>AC: state = AuthState.unauthenticated() -> GoRouter chuyển về /sign-in
```

