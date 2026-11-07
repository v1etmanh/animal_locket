package com.animallocket.outbox;

import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.EventJson;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Gọi trong cùng transaction với thay đổi dữ liệu để event không bao giờ mất hoặc ghi đôi. */
public class OutboxService {
    private final OutboxRepository repository;
    private final String producer;

    public OutboxService(OutboxRepository repository, String producer) {
        this.repository = repository;
        this.producer = producer;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public EventEnvelope publish(String topic, String type, String key, Object payload) {
        EventEnvelope envelope = EventEnvelope.of(type, producer, key, payload);
        repository.save(new OutboxEvent(envelope.eventId(), topic, key, type, EventJson.write(envelope)));
        return envelope;
    }
}
