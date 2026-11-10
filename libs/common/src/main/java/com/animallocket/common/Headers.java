package com.animallocket.common;

/** Tên header dùng chung giữa gateway và các service. */
public final class Headers {
    /** publicId của người gọi, do gateway gắn sau khi xác thực JWT. Client không bao giờ được tự đặt. */

    //
    public static final String PUBLIC_ID = "X-Public-Id";
    // PUBLIC ID ĐỊNH DANH NGƯỜI DÙNG -> SUY DC RATELIMIT ÁP DỤNG TẠI ĐÂY
    /** Khoá gọi nội bộ service-to-service cho các endpoint /internal/**. */
    public static final String INTERNAL_TOKEN = "X-Internal-Token";
    public static final String CORRELATION_ID = "X-Correlation-Id";
    public static final String IDEMPOTENCY_KEY = "Idempotency-Key";

    private Headers() {
    }
}
