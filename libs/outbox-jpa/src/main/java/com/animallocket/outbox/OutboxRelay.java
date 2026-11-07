package com.animallocket.outbox;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.TimeUnit;

/** Đọc outbox theo thứ tự và đẩy lên Kafka. Dừng ở lỗi đầu tiên để giữ thứ tự. */
public class OutboxRelay {
    private static final Logger log = LoggerFactory.getLogger(OutboxRelay.class);

    private final OutboxRepository repository;
    private final KafkaTemplate<String, String> kafka;

    public OutboxRelay(OutboxRepository repository, KafkaTemplate<String, String> kafka) {
        this.repository = repository;
        this.kafka = kafka;
    }

    @Scheduled(fixedDelayString = "${animal.outbox.relay.interval-ms:500}")
    @Transactional
    public void relay() {
        List<OutboxEvent> batch = repository.findTop100ByPublishedAtIsNullOrderByCreatedAtAsc();
        for (OutboxEvent e : batch) {
            try {
                kafka.send(e.getTopic(), e.getKey(), e.getPayload()).get(5, TimeUnit.SECONDS);
                e.markPublished();
            } catch (Exception ex) {
                if (ex instanceof InterruptedException) {
                    Thread.currentThread().interrupt();
                }
                log.warn("Đẩy event {} ({}) thất bại, sẽ thử lại: {}", e.getId(), e.getType(), ex.toString());
                break;
            }
        }
    }

    @Scheduled(fixedDelay = 3_600_000)
    @Transactional
    public void cleanup() {
        int n = repository.deletePublishedBefore(Instant.now().minus(Duration.ofDays(1)));
        if (n > 0) {
            log.debug("Dọn {} event outbox đã đẩy", n);
        }
    }
}
