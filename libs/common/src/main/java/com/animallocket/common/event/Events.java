package com.animallocket.common.event;

import java.time.Instant;

/** Payload của từng loại event. Chỉ chứa publicId, không bao giờ chứa email/SĐT/sub. */
public final class Events {
    private Events() {
    }

    public record UserRegistered(String publicId, String ageGroup, String leadAnimal) {
    }

    public record UserDeleted(String publicId) {
    }

    public record UserBlocked(String blockerPublicId, String blockedPublicId) {
    }

    public record LeadAnimalChanged(String publicId, String leadAnimal) {
    }

    public record FriendRequestReceived(String fromPublicId, String toPublicId) {
    }

    public record FriendAccepted(String userAPublicId, String userBPublicId) {
    }

    /** Huỷ kết bạn: post/chat dọn cache và đóng hội thoại. */
    public record FriendRemoved(String userAPublicId, String userBPublicId) {
    }

    /** Người dùng tắt chế độ khám phá: discovery phải xoá vị trí ngay (không chờ TTL). */
    public record DiscoveryDisabled(String publicId) {
    }

    /** context: POST hoặc CHAT. refId: id bài đăng (POST) hoặc id hội thoại (CHAT). */
    public record PhotoUploaded(String mediaId, String ownerPublicId, String rawKey, String leadAnimal,
                                String context, String refId) {
    }

    /** method: AI, STICKER hoặc NONE (ảnh không có mặt). */
    public record PhotoReady(String mediaId, String ownerPublicId, String publicKey, String method,
                             int facesDetected, String context, String refId) {
    }

    public record PhotoRejected(String mediaId, String ownerPublicId, String reason, String context,
                                String refId) {
    }

    /** Do face-worker phát khi xử lý xong. */
    public record FaceProcessed(String mediaId, String ownerPublicId, String publicKey, String method,
                                int facesDetected) {
    }

    /** Do face-worker phát khi hết lượt retry hoặc ảnh không hợp lệ. */
    public record FaceFailed(String mediaId, String ownerPublicId, String reason) {
    }

    public record PostPublished(String postId, String authorPublicId) {
    }

    public record PostLiked(String postId, String authorPublicId, String likerPublicId) {
    }

    public record PostCommented(String postId, String authorPublicId, String commenterPublicId) {
    }

    public record MessageSent(String conversationId, String senderPublicId, String recipientPublicId) {
    }

    public record SubscriptionChanged(String publicId, String plan, Instant expiresAt) {
    }

    /** item: BOOST, PRIORITY_INVITE, ANIMAL_PACK:<code>. */
    public record ConsumableGranted(String publicId, String item, int quantity) {
    }
}
