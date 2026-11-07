package com.animallocket.common.config;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.kafka.KafkaAutoConfiguration;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.cloud.circuitbreaker.resilience4j.Resilience4JAutoConfiguration;
import org.springframework.cloud.client.circuitbreaker.CircuitBreakerFactory;
import org.springframework.kafka.listener.CommonErrorHandler;
import org.springframework.kafka.listener.DefaultErrorHandler;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InfrastructureAutoConfigurationTest {

    // ---------------- Resilience4j ----------------

    private final ApplicationContextRunner resilience = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(
                    io.github.resilience4j.springboot3.circuitbreaker.autoconfigure.CircuitBreakerAutoConfiguration.class,
                    io.github.resilience4j.springboot3.timelimiter.autoconfigure.TimeLimiterAutoConfiguration.class,
                    Resilience4JAutoConfiguration.class, ResilienceAutoConfiguration.class));

    @Test
    void slowCallsAreCutOffByTheConfiguredTimeoutAndFallBack() {
        resilience.withPropertyValues("animal.resilience.timeout=200ms").run(ctx -> {
            CircuitBreakerFactory<?, ?> factory = ctx.getBean(CircuitBreakerFactory.class);
            long start = System.nanoTime();
            String r = factory.create("slow").run(() -> {
                try {
                    Thread.sleep(3000);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                return "finished";
            }, t -> "fallback");
            long ms = (System.nanoTime() - start) / 1_000_000;
            assertEquals("fallback", r);
            assertTrue(ms < 1500, "phải bị cắt theo timeout cấu hình, nhưng mất " + ms + " ms");
        });
    }

    @Test
    void fastCallsPassThroughUntouched() {
        resilience.run(ctx -> assertEquals("ok", ctx.getBean(CircuitBreakerFactory.class).create("fast").run(() -> "ok", t -> "fb")));
    }

    @Test
    void circuitOpensAfterRepeatedFailuresAndShortCircuits() {
        resilience.withPropertyValues("animal.resilience.open-wait=30s").run(ctx -> {
            CircuitBreakerFactory<?, ?> factory = ctx.getBean(CircuitBreakerFactory.class);
            int[] real = {0};
            for (int i = 0; i < 40; i++) {
                factory.create("flaky").run(() -> {
                    real[0]++;
                    throw new IllegalStateException("down");
                }, t -> "fb");
            }
            // Cửa sổ 10 lời gọi tối thiểu rồi mở mạch: các lời gọi sau không còn chạm tới dịch vụ.
            assertTrue(real[0] >= 10 && real[0] < 40, "số lời gọi thật: " + real[0]);
        });
    }

    // ---------------- Kafka DLQ ----------------

    private final ApplicationContextRunner kafka = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(KafkaAutoConfiguration.class, KafkaErrorHandlingAutoConfiguration.class))
            .withPropertyValues("spring.kafka.bootstrap-servers=localhost:9092");

    @Test
    void consumersGetADeadLetterErrorHandlerByDefault() {
        kafka.run(ctx -> assertTrue(ctx.getBean(CommonErrorHandler.class) instanceof DefaultErrorHandler));
    }

    @Test
    void servicesCanOverrideTheErrorHandler() {
        CommonErrorHandler custom = new DefaultErrorHandler();
        kafka.withBean("custom", CommonErrorHandler.class, () -> custom)
                .run(ctx -> assertSame(custom, ctx.getBean(CommonErrorHandler.class)));
    }

    @Test
    void failedRecordsGoToTheTopicDlq() {
        var rec = new ConsumerRecord<>("media.results", 3, 42L, "k", "v");
        var tp = KafkaErrorHandlingAutoConfiguration.dlqDestination(rec, new RuntimeException("boom"));
        assertEquals("media.results.dlq", tp.topic());
        assertEquals(-1, tp.partition());
    }
}
