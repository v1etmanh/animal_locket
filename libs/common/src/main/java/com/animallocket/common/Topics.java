package com.animallocket.common;

/** Kafka topic. Khoá message luôn là publicId liên quan (hoặc mediaId) để giữ thứ tự theo thực thể. */
public final class Topics {
    public static final String USER = "user.events";
    public static final String FRIEND = "friend.events";
    public static final String MEDIA = "media.events";
    public static final String POST = "post.events";
    public static final String CHAT = "chat.events";
    public static final String BILLING = "billing.events";
    /** Kết quả thô do face-worker phát; media-service chuyển thành PHOTO_READY/REJECTED qua outbox. */
    public static final String MEDIA_RESULTS = "media.results";
    public static final String MEDIA_DLQ = "media.events.dlq";

    private Topics() {
    }
}
