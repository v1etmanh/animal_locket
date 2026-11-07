package com.animallocket.common.config;

import com.animallocket.common.web.ApiExceptionHandler;
import com.animallocket.common.web.InternalTokenFilter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.www.BasicAuthenticationFilter;

/**
 * Cấu hình chung cho mọi service servlet: xử lý lỗi RFC 7807, bảo vệ /internal/**,
 * và kiểm tra lại JWT (gateway đã kiểm tra một lần, service kiểm tra lần nữa).
 *
 * <ul>
 *   <li>{@code animal.security.enabled=false}: tắt kiểm tra JWT (dùng cho test).</li>
 *   <li>{@code animal.security.public-paths}: đường dẫn không cần JWT (ví dụ /ws/** của chat).</li>
 *   <li>{@code animal.internal-token}: khoá gọi nội bộ.</li>
 * </ul>
 */
@AutoConfiguration
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
@Import(ApiExceptionHandler.class)
public class CommonAutoConfiguration {

    @Bean
    InternalTokenFilter internalTokenFilter(
            @Value("${animal.internal-token:dev-internal-token}") String token) {
        return new InternalTokenFilter(token);
    }

    @Bean
    @ConditionalOnMissingBean(SecurityFilterChain.class)
    SecurityFilterChain animalSecurityFilterChain(
            HttpSecurity http,
            InternalTokenFilter internalTokenFilter,
            @Value("${animal.security.enabled:true}") boolean enabled,
            @Value("${animal.security.public-paths:}") String[] publicPaths) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .addFilterBefore(internalTokenFilter, BasicAuthenticationFilter.class);
        if (!enabled) {
            http.authorizeHttpRequests(a -> a.anyRequest().permitAll());
            return http.build();
        }
        http.authorizeHttpRequests(a -> {
                    a.requestMatchers("/actuator/health/**", "/actuator/prometheus", "/actuator/info").permitAll();
                    a.requestMatchers("/internal/**").permitAll(); // đã có InternalTokenFilter
                    a.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();
                    if (publicPaths.length > 0 && !publicPaths[0].isBlank()) {
                        a.requestMatchers(publicPaths).permitAll();
                    }
                    a.anyRequest().authenticated();
                })
                .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
