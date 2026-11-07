package com.animallocket.common.kv;

import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;

/**
 * Mặc định dùng Redis ({@code animal.kv.type=redis}). Đặt {@code animal.kv.type=memory} cho test.
 */
@AutoConfiguration(after = RedisAutoConfiguration.class)
public class KeyValueAutoConfiguration {

    @Configuration(proxyBeanMethods = false)
    @ConditionalOnProperty(name = "animal.kv.type", havingValue = "memory")
    static class Memory {
        @Bean
        @ConditionalOnMissingBean(KeyValueStore.class)
        KeyValueStore inMemoryKeyValueStore() {
            return new InMemoryKeyValueStore();
        }
    }

    @Configuration(proxyBeanMethods = false)
    @org.springframework.boot.autoconfigure.condition.ConditionalOnClass(StringRedisTemplate.class)
    @ConditionalOnProperty(name = "animal.kv.type", havingValue = "redis", matchIfMissing = true)
    static class Redis {
        @Bean
        @ConditionalOnMissingBean(KeyValueStore.class)
        @org.springframework.boot.autoconfigure.condition.ConditionalOnBean(StringRedisTemplate.class)
        KeyValueStore redisKeyValueStore(StringRedisTemplate template) {
            return new RedisKeyValueStore(template);
        }
    }
}
