package com.animallocket.outbox;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.binder.MeterBinder;

import java.time.Duration;
import java.time.Instant;

/** {@code outbox_pending} và {@code outbox_oldest_pending_age_seconds}; lỗi đọc DB trả NaN thay vì làm hỏng scrape. */
public class OutboxMetrics implements MeterBinder {
    private final OutboxRepository repository;

    public OutboxMetrics(OutboxRepository repository) {
        this.repository = repository;
    }

    double pending() {
        try {
            return repository.countByPublishedAtIsNull();
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    double oldestAgeSeconds() {
        try {
            Instant oldest = repository.oldestUnpublishedCreatedAt();
            return oldest == null ? 0 : Math.max(0, Duration.between(oldest, Instant.now()).toMillis() / 1000.0);
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    @Override
    public void bindTo(MeterRegistry registry) {
        Gauge.builder("outbox.pending", this, OutboxMetrics::pending)
                .description("Số event outbox chưa được đẩy lên Kafka").register(registry);
        Gauge.builder("outbox.oldest.pending.age", this, OutboxMetrics::oldestAgeSeconds)
                .baseUnit("seconds").description("Tuổi event outbox chưa đẩy cũ nhất").register(registry);
    }
}
