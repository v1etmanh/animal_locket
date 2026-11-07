package com.animallocket.outbox;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class OutboxMetricsTest {
    @Test
    void exposesPendingAndOldestAge() {
        OutboxRepository repo = mock(OutboxRepository.class);
        when(repo.countByPublishedAtIsNull()).thenReturn(7L);
        when(repo.oldestUnpublishedCreatedAt()).thenReturn(Instant.now().minusSeconds(120));
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        new OutboxMetrics(repo).bindTo(registry);
        assertEquals(7.0, registry.get("outbox.pending").gauge().value());
        assertTrue(registry.get("outbox.oldest.pending.age").gauge().value() >= 119);
    }

    @Test
    void emptyOutboxHasZeroAge() {
        OutboxRepository repo = mock(OutboxRepository.class);
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        new OutboxMetrics(repo).bindTo(registry);
        assertEquals(0.0, registry.get("outbox.oldest.pending.age").gauge().value());
    }
}
