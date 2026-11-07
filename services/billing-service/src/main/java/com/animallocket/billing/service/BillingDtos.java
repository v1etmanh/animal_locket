package com.animallocket.billing.service;

import com.animallocket.billing.domain.Product;
import com.animallocket.billing.domain.Store;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.Map;

public final class BillingDtos {
    private BillingDtos() {
    }

    /** token = transactionId (Apple) hoặc purchaseToken (Google). Server luôn tự hỏi lại store, không tin client. */
    public record VerifyRequest(@NotNull Store store, @NotBlank @Size(max = 100) String sku,
                                @NotBlank @Size(max = 4096) String token) {
    }

    public record MeResponse(String plan, Instant planExpiresAt, Map<String, Integer> wallet) {
    }

    public record ProductView(String sku, Product.Type type, String item, int quantity) {
    }

    public record ConsumeRequest(@NotBlank String publicId, @NotBlank String item) {
    }
}
