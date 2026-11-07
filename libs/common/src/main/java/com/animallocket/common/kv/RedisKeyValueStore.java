package com.animallocket.common.kv;

import org.springframework.data.redis.core.StringRedisTemplate;

import java.time.Duration;
import java.util.Optional;

public class RedisKeyValueStore implements KeyValueStore {
    private final StringRedisTemplate redis;

    public RedisKeyValueStore(StringRedisTemplate redis) {
        this.redis = redis;
    }

    @Override
    public long increment(String key, Duration ttlIfNew) {
        Long v = redis.opsForValue().increment(key);
        if (v != null && v == 1L) {
            redis.expire(key, ttlIfNew);
        }
        return v == null ? 0 : v;
    }

    @Override
    public void decrement(String key) {
        Long v = redis.opsForValue().decrement(key);
        if (v != null && v < 0) {
            redis.opsForValue().increment(key);
        }
    }

    @Override
    public Optional<String> get(String key) {
        return Optional.ofNullable(redis.opsForValue().get(key));
    }

    @Override
    public void set(String key, String value, Duration ttl) {
        if (ttl == null) {
            redis.opsForValue().set(key, value);
        } else {
            redis.opsForValue().set(key, value, ttl);
        }
    }

    @Override
    public boolean setIfAbsent(String key, String value, Duration ttl) {
        return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(key, value, ttl));
    }

    @Override
    public void delete(String... keys) {
        redis.delete(java.util.List.of(keys));
    }
}
