package com.animallocket.billing.service;

import com.animallocket.billing.domain.Product;
import com.animallocket.billing.domain.Purchase;
import com.animallocket.billing.domain.Store;
import com.animallocket.billing.domain.Subscription;
import com.animallocket.billing.domain.WebhookEvent;
import com.animallocket.billing.repo.ProductRepository;
import com.animallocket.billing.repo.PurchaseRepository;
import com.animallocket.billing.repo.SubscriptionRepository;
import com.animallocket.billing.repo.WebhookEventRepository;
import com.animallocket.billing.store.VerifiedPurchase;
import com.animallocket.common.EventTypes;
import com.animallocket.common.Topics;
import com.animallocket.common.event.Events;
import com.animallocket.common.web.ApiException;
import com.animallocket.outbox.OutboxService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Nguyên tắc: quyền lợi CHỈ được cấp sau khi store xác nhận giao dịch (fail closed), và việc cấp quyền
 * (ghi DB + phát event) nằm trong một transaction. Client chỉ "kết thúc giao dịch" với store sau khi nhận 200
 * từ đây, nên người dùng không bao giờ bị trừ tiền mà không có quyền lợi.
 */
@Service
public class BillingService {
    private static final Logger log = LoggerFactory.getLogger(BillingService.class);
    static final Set<String> CONSUMABLE_ITEMS = Set.of("BOOST", "PRIORITY_INVITE");

    private final ProductRepository products;
    private final PurchaseRepository purchases;
    private final SubscriptionRepository subscriptions;
    private final WebhookEventRepository webhooks;
    private final WalletService wallet;
    private final OutboxService outbox;

    public BillingService(ProductRepository products, PurchaseRepository purchases, SubscriptionRepository subscriptions,
                          WebhookEventRepository webhooks, WalletService wallet, OutboxService outbox) {
        this.products = products;
        this.purchases = purchases;
        this.subscriptions = subscriptions;
        this.webhooks = webhooks;
        this.wallet = wallet;
        this.outbox = outbox;
    }

    @Transactional(readOnly = true)
    public List<BillingDtos.ProductView> catalog() {
        return products.findByActiveTrueOrderBySku().stream()
                .map(p -> new BillingDtos.ProductView(p.getSku(), p.getType(), p.getItem(), p.getQuantity())).toList();
    }

    @Transactional(readOnly = true)
    public BillingDtos.MeResponse me(String publicId) {
        var active = subscriptions.findFirstByPublicIdAndStatusAndExpiresAtAfterOrderByExpiresAtDesc(
                publicId, Subscription.Status.ACTIVE, Instant.now());
        return new BillingDtos.MeResponse(active.isPresent() ? "PRO" : "FREE",
                active.map(Subscription::getExpiresAt).orElse(null), wallet.balances(publicId));
    }

    @Transactional
    public BillingDtos.MeResponse grant(String me, Store store, Product product, VerifiedPurchase vp) {
        var existing = purchases.findByStoreAndStoreTransactionId(store, vp.transactionId());
        if (existing.isPresent()) {
            if (!existing.get().getPublicId().equals(me)) {
                throw ApiException.conflict("RECEIPT_ALREADY_USED", "Biên lai này đã được dùng cho tài khoản khác");
            }
            return me(me);
        }
        Purchase p = new Purchase();
        p.setStore(store);
        p.setStoreTransactionId(vp.transactionId());
        p.setOriginalTransactionId(vp.originalTransactionId());
        p.setPublicId(me);
        p.setSku(product.getSku());
        purchases.save(p);

        switch (product.getType()) {
            case SUBSCRIPTION -> grantSubscription(me, store, product, vp);
            case CONSUMABLE -> {
                if (!CONSUMABLE_ITEMS.contains(product.getItem())) {
                    throw new IllegalStateException("Vật phẩm không hợp lệ: " + product.getItem());
                }
                wallet.credit(me, product.getItem(), product.getQuantity(), "PURCHASE", "purchase:" + p.getId());
                outbox.publish(Topics.BILLING, EventTypes.CONSUMABLE_GRANTED, me,
                        new Events.ConsumableGranted(me, product.getItem(), product.getQuantity()));
            }
            case PACK -> outbox.publish(Topics.BILLING, EventTypes.CONSUMABLE_GRANTED, me,
                    new Events.ConsumableGranted(me, "ANIMAL_PACK:" + product.getItem(), 1));
        }
        return me(me);
    }

    private void grantSubscription(String me, Store store, Product product, VerifiedPurchase vp) {
        if (vp.expiresAt() == null) {
            throw ApiException.badRequest("INVALID_RECEIPT", "Thuê bao thiếu hạn sử dụng");
        }
        Subscription sub = subscriptions.findByStoreAndOriginalTransactionId(store, vp.originalTransactionId())
                .orElseGet(() -> {
                    Subscription s = new Subscription();
                    s.setPublicId(me);
                    s.setStore(store);
                    s.setOriginalTransactionId(vp.originalTransactionId());
                    return s;
                });
        if (!sub.getPublicId().equals(me)) {
            throw ApiException.conflict("RECEIPT_ALREADY_USED", "Thuê bao này đã gắn với tài khoản khác");
        }
        sub.setSku(product.getSku());
        sub.setExpiresAt(vp.expiresAt());
        sub.setStatus(vp.expiresAt().isAfter(Instant.now()) ? Subscription.Status.ACTIVE : Subscription.Status.EXPIRED);
        sub.setUpdatedAt(Instant.now());
        subscriptions.save(sub);
        refreshEntitlement(me);
    }

    /** Phát event theo trạng thái Pro hiện tại của người dùng (có thể có nhiều thuê bao ở các store khác nhau). */
    void refreshEntitlement(String publicId) {
        Instant now = Instant.now();
        var active = subscriptions.findFirstByPublicIdAndStatusAndExpiresAtAfterOrderByExpiresAtDesc(
                publicId, Subscription.Status.ACTIVE, now);
        if (active.isPresent()) {
            outbox.publish(Topics.BILLING, EventTypes.SUBSCRIPTION_ACTIVATED, publicId,
                    new Events.SubscriptionChanged(publicId, "PRO", active.get().getExpiresAt()));
        } else {
            outbox.publish(Topics.BILLING, EventTypes.SUBSCRIPTION_EXPIRED, publicId,
                    new Events.SubscriptionChanged(publicId, "FREE", null));
        }
    }

    // ---------------- dùng vật phẩm (discovery gọi nội bộ) ----------------

    @Transactional
    public void consume(String publicId, String item) {
        if (!CONSUMABLE_ITEMS.contains(item)) {
            throw ApiException.badRequest("UNKNOWN_ITEM", "Vật phẩm không hợp lệ");
        }
        if (!wallet.debit(publicId, item, 1, "CONSUME", UUID.randomUUID().toString())) {
            throw ApiException.conflict("INSUFFICIENT_BALANCE", "Không đủ số dư");
        }
    }

    // ---------------- webhook / gia hạn / hoàn tiền ----------------

    /** @return false nếu thông báo này đã xử lý trước đó (store gửi lại). */
    @Transactional
    public boolean firstTimeWebhook(String id, Store store, String type) {
        if (webhooks.existsById(id)) {
            return false;
        }
        webhooks.save(new WebhookEvent(id, store.name(), type));
        return true;
    }

    /** Gia hạn hoặc đổi hạn từ store. Không có thuê bao khớp thì bỏ qua (client sẽ xác thực lại khi mở app). */
    @Transactional
    public boolean onSubscriptionUpdated(Store store, String originalTransactionId, Instant expiresAt) {
        return subscriptions.findByStoreAndOriginalTransactionId(store, originalTransactionId).map(sub -> {
            sub.setExpiresAt(expiresAt);
            sub.setStatus(expiresAt.isAfter(Instant.now()) ? Subscription.Status.ACTIVE : Subscription.Status.EXPIRED);
            sub.setUpdatedAt(Instant.now());
            refreshEntitlement(sub.getPublicId());
            return true;
        }).orElse(false);
    }

    /** Thuê bao kết thúc (hết hạn, bị thu hồi, hoàn tiền). */
    @Transactional
    public boolean onSubscriptionEnded(Store store, String originalTransactionId) {
        return subscriptions.findByStoreAndOriginalTransactionId(store, originalTransactionId).map(sub -> {
            sub.setStatus(Subscription.Status.EXPIRED);
            sub.setExpiresAt(Instant.now());
            sub.setUpdatedAt(Instant.now());
            refreshEntitlement(sub.getPublicId());
            return true;
        }).orElse(false);
    }

    /** Hoàn tiền một giao dịch: thu hồi quyền lợi tương ứng. Gói con vật đã mở thì giữ nguyên (xem tài liệu). */
    @Transactional
    public boolean onRefund(Store store, String transactionId) {
        return purchases.findByStoreAndStoreTransactionId(store, transactionId).map(p -> {
            if (p.getStatus() == Purchase.Status.REFUNDED) {
                return true;
            }
            p.setStatus(Purchase.Status.REFUNDED);
            Product product = products.findById(p.getSku()).orElse(null);
            if (product == null) {
                return true;
            }
            switch (product.getType()) {
                case SUBSCRIPTION -> {
                    if (p.getOriginalTransactionId() != null) {
                        onSubscriptionEnded(store, p.getOriginalTransactionId());
                    }
                }
                case CONSUMABLE -> {
                    // Thu hồi tối đa số dư còn lại: phần đã dùng thì không lấy lại được.
                    int n = product.getQuantity();
                    while (n > 0 && !wallet.debit(p.getPublicId(), product.getItem(), n, "REFUND", "refund:" + p.getId() + ":" + n)) {
                        n--;
                    }
                }
                case PACK -> log.info("Hoàn tiền gói {} của {}: giữ nguyên con vật đã mở", product.getItem(), p.getPublicId());
            }
            return true;
        }).orElse(false);
    }

    /** Thuê bao quá hạn quá thời gian ân hạn mà chưa có gia hạn thì hạ về miễn phí. */
    @Transactional
    public int expireDue(Duration grace) {
        Instant cutoff = Instant.now().minus(grace);
        int n = 0;
        for (Subscription s : subscriptions.findByStatusAndExpiresAtBefore(Subscription.Status.ACTIVE, cutoff)) {
            s.setStatus(Subscription.Status.EXPIRED);
            s.setUpdatedAt(Instant.now());
            refreshEntitlement(s.getPublicId());
            n++;
        }
        return n;
    }

    // ---------------- xoá tài khoản ----------------

    @Transactional
    public void onUserDeleted(String publicId) {
        wallet.wipe(publicId);
        subscriptions.deleteByPublicId(publicId);
        purchases.anonymize(publicId);
    }
}
