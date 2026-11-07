package com.animallocket.common.config;

import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.timelimiter.TimeLimiterConfig;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.cloud.circuitbreaker.resilience4j.Resilience4JCircuitBreakerFactory;
import org.springframework.cloud.circuitbreaker.resilience4j.Resilience4JConfigBuilder;
import org.springframework.cloud.client.circuitbreaker.Customizer;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

import java.time.Duration;

/**
 * Cấu hình mặc định cho mọi lời gọi đồng bộ qua {@code CircuitBreakerFactory}.
 *
 * <p>Vì sao cần: các khoá {@code resilience4j.timelimiter.*} trong YAML áp dụng cho annotation/registry của
 * Resilience4j, KHÔNG tự áp dụng cho {@code CircuitBreakerFactory} của Spring Cloud; không cấu hình thì time limiter
 * mặc định chỉ 1 giây. Ở đây đặt tường minh: timeout {@code animal.resilience.timeout} (mặc định 2 giây),
 * mở mạch khi ≥ 50% lỗi trên cửa sổ 20 lời gọi, thử lại sau 10 giây.
 */
@AutoConfiguration
@ConditionalOnClass(Resilience4JCircuitBreakerFactory.class)
public class ResilienceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean(name = "animalDefaultCircuitBreakerCustomizer")
    Customizer<Resilience4JCircuitBreakerFactory> animalDefaultCircuitBreakerCustomizer(Environment env) {
        Binder binder = Binder.get(env);
        Duration timeout = binder.bind("animal.resilience.timeout", Duration.class).orElse(Duration.ofSeconds(2));
        Duration openWait = binder.bind("animal.resilience.open-wait", Duration.class).orElse(Duration.ofSeconds(10));
        return factory -> factory.configureDefault(id -> new Resilience4JConfigBuilder(id)
                .circuitBreakerConfig(CircuitBreakerConfig.custom()
                        .slidingWindowSize(20)
                        .minimumNumberOfCalls(10)
                        .failureRateThreshold(50)
                        .waitDurationInOpenState(openWait)
                        .permittedNumberOfCallsInHalfOpenState(5)
                        .build())
                .timeLimiterConfig(TimeLimiterConfig.custom().timeoutDuration(timeout).build())
                .build());
    }
}
