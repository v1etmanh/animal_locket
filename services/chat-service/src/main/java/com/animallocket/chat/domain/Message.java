package com.animallocket.chat.domain;

import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/** Index (conversationId, createdAt) phục vụ phân trang lịch sử theo thời gian. */
@Document("messages")
@CompoundIndex(name = "conv_created", def = "{'conversationId': 1, 'createdAt': -1}")
@Getter
@NoArgsConstructor
public class Message {
    public enum Type { TEXT, IMAGE }

    @Id
    private String id;
    private String conversationId;
    private String senderId;
    private Type type;
    private String text;
    /** Ảnh trong chat cũng đi qua media pipeline: chỉ lưu mediaId của ảnh đã ẩn mặt. */
    private String mediaId;
    private Instant createdAt = Instant.now();

    public Message(String conversationId, String senderId, Type type, String text, String mediaId) {
        this.conversationId = conversationId;
        this.senderId = senderId;
        this.type = type;
        this.text = text;
        this.mediaId = mediaId;
    }
}
