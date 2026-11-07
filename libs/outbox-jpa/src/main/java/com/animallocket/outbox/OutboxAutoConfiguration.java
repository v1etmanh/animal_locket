package com.animallocket.outbox;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.AutoConfigurationPackage;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Đăng ký entity/repository của outbox vào JPA của service và bật relay.
 * {@code @AutoConfigurationPackage} thêm package này vào danh sách quét entity.
 *
 * <p>{@code after = KafkaAutoConfiguration}: nếu không, {@code @ConditionalOnBean(KafkaTemplate)} có thể được đánh giá
 * TRƯỚC khi KafkaTemplate tồn tại và OutboxRelay âm thầm không bao giờ được tạo (event kẹt trong bảng outbox).
 */
@AutoConfiguration(after = org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration.class)
@AutoConfigurationPackage
@EnableScheduling
public class OutboxAutoConfiguration {

    @Bean
    OutboxService outboxService(OutboxRepository repository,
                                @Value("${spring.application.name:unknown}") String producer) {
        return new OutboxService(repository, producer);
    }

    @Bean
    IdempotencyService idempotencyService(ProcessedEventRepository repository) {
        return new IdempotencyService(repository);
    }

    /** Metric độ trễ outbox: số dòng chưa đẩy và tuổi dòng cũ nhất (giây) — cảnh báo "Outbox kẹt". */
    @Bean
    @ConditionalOnBean(io.micrometer.core.instrument.MeterRegistry.class)
    OutboxMetrics outboxMetrics(OutboxRepository repository, io.micrometer.core.instrument.MeterRegistry registry) {
        OutboxMetrics metrics = new OutboxMetrics(repository);
        metrics.bindTo(registry);
        return metrics;
    }

    @Bean
    @ConditionalOnBean(KafkaTemplate.class)
    @ConditionalOnProperty(name = "animal.outbox.relay.enabled", havingValue = "true", matchIfMissing = true)
    OutboxRelay outboxRelay(OutboxRepository repository, KafkaTemplate<String, String> kafka) {
        return new OutboxRelay(repository, kafka);
    }
}
