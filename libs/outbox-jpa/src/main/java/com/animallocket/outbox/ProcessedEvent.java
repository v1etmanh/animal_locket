package com.animallocket.outbox;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

/** Dấu vết event đã xử lý, giúp consumer idempotent. */
@Entity
@Table(name = "processed_events")
public class ProcessedEvent {
    @Id
    @Column(length = 36)
    private String eventId;
    @Column(nullable = false)
    private Instant processedAt;

    protected ProcessedEvent() {
    }

    public ProcessedEvent(String eventId) {
        this.eventId = eventId;
        this.processedAt = Instant.now();
    }

    public String getEventId() {
        return eventId;
    }
}
