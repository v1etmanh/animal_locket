package com.animallocket.common.event;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.Instant;
import java.util.UUID;

/**
 * Phong bì chung cho mọi event Kafka. Payload là JSON tự do theo từng {@code type}
 * (xem {@link Events}). {@code eventId} dùng để consumer khử trùng lặp.
 */
public record EventEnvelope(
        String eventId,
        String type,
        int version,
        Instant occurredAt,
        String producer,
        String correlationId,
        String key,
        JsonNode payload) {

    public static EventEnvelope of(String type, String producer, String key, Object payload) {
        return new EventEnvelope(
                UUID.randomUUID().toString(), type, 1, Instant.now(), producer, null, key,
                EventJson.mapper().valueToTree(payload));
    }

    public <T> T payloadAs(Class<T> clazz) {
        try {
            return EventJson.mapper().treeToValue(payload, clazz);
        } catch (Exception e) {
            throw new IllegalArgumentException("Payload không hợp lệ cho event " + type, e);
        }
    }
}
