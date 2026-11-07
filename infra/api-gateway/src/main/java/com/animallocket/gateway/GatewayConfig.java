package com.animallocket.gateway;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Objects;

@Configuration
@EnableWebFluxSecurity
public class GatewayConfig {

    /**
     * Gateway kiểm tra JWT một lần ở biên. Webhook của store không có JWT (billing tự xác thực chữ ký).
     * {@code animal.security.enabled=false} chỉ dành cho test cục bộ.
     */
    @Bean
    SecurityWebFilterChain securityChain(ServerHttpSecurity http,
                                         @Value("${animal.security.enabled:true}") boolean enabled) {
        http.csrf(ServerHttpSecurity.CsrfSpec::disable);
        if (!enabled) {
            return http.authorizeExchange(a -> a.anyExchange().permitAll()).build();
        }
        return http.authorizeExchange(a -> a
                        .pathMatchers("/actuator/health/**", "/actuator/prometheus", "/fallback/**").permitAll()
                        .pathMatchers("/webhooks/**").permitAll()
                        .pathMatchers(HttpMethod.OPTIONS).permitAll()
                        .anyExchange().authenticated())
                .oauth2ResourceServer(o -> o.jwt(j -> {
                }))
                .build();
    }

    @Bean
    @LoadBalanced
    WebClient.Builder loadBalancedWebClientBuilder() {
        return WebClient.builder();
    }

    /**
     * Rate limit theo publicId nếu có, nếu không thì theo IP thật của client. Gateway luôn đứng sau Traefik nên
     * IP kết nối là của Traefik; phải đọc X-Forwarded-For (tin tối đa 1 proxy, tức Traefik) để mỗi người một bucket.
     */
    @Bean
    KeyResolver userOrIpKeyResolver() {
        var resolver = org.springframework.cloud.gateway.support.ipresolver.XForwardedRemoteAddressResolver.maxTrustedIndex(1);
        return exchange -> {
            String id = exchange.getRequest().getHeaders().getFirst("X-Public-Id");
            if (id != null && !id.isBlank()) {
                return Mono.just("u:" + id);
            }
            var addr = resolver.resolve(exchange);
            return Mono.just("ip:" + (addr == null || addr.getAddress() == null
                    ? "unknown" : Objects.toString(addr.getAddress().getHostAddress())));
        };
    }
}
