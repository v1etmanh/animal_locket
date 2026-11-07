package com.animallocket.outbox;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

/**
 * Hồi quy: trước đây OutboxAutoConfiguration dùng {@code @ConditionalOnBean(KafkaTemplate)} nhưng không khai báo
 * thứ tự sau KafkaAutoConfiguration, nên relay có thể không bao giờ được tạo và event kẹt vĩnh viễn trong bảng outbox.
 * Các test cấp service luôn tắt relay nên không phát hiện được lỗi này.
 */
class OutboxAutoConfigurationOrderingTest {
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            // Cố ý liệt kê Outbox TRƯỚC Kafka để chứng minh thứ tự do @AutoConfiguration(after=...) quyết định.
            .withConfiguration(AutoConfigurations.of(OutboxAutoConfiguration.class, KafkaAutoConfiguration.class))
            .withBean(OutboxRepository.class, () -> mock(OutboxRepository.class))
            .withBean(ProcessedEventRepository.class, () -> mock(ProcessedEventRepository.class))
            .withPropertyValues("spring.kafka.bootstrap-servers=localhost:9092", "spring.application.name=test");

    @Test
    void relayIsCreatedWhenKafkaIsPresent() {
        runner.run(ctx -> {
            assertTrue(ctx.containsBean("outboxRelay"), "OutboxRelay phải được tạo khi có KafkaTemplate");
            assertEquals(1, ctx.getBeansOfType(OutboxRelay.class).size());
        });
    }

    @Test
    void relayCanBeDisabledByProperty() {
        runner.withPropertyValues("animal.outbox.relay.enabled=false")
                .run(ctx -> assertFalse(ctx.containsBean("outboxRelay")));
    }

    @Test
    void idempotencyAndOutboxServicesAlwaysPresent() {
        runner.run(ctx -> {
            assertTrue(ctx.containsBean("outboxService"));
            assertTrue(ctx.containsBean("idempotencyService"));
        });
    }
}
