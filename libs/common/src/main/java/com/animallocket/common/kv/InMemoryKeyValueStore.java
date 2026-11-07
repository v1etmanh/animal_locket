package com.animallocket.common.kv;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public class InMemoryKeyValueStore implements KeyValueStore {
    private record Entry(String value, Instant expiresAt) {
        boolean expired() {
            return expiresAt != null && !expiresAt.isAfter(Instant.now());
        }
    }

    private final Map<String, Entry> data = new ConcurrentHashMap<>();

    @Override
    public long increment(String key, Duration ttlIfNew) {
        return Long.parseLong(data.compute(key, (k, old) -> {
            if (old == null || old.expired()) {
                return new Entry("1", Instant.now().plus(ttlIfNew));
            }
            return new Entry(String.valueOf(Long.parseLong(old.value) + 1), old.expiresAt);
        }).value);
    }

    @Override
    public void decrement(String key) {
        data.computeIfPresent(key, (k, old) -> old.expired() ? null
                : new Entry(String.valueOf(Math.max(0, Long.parseLong(old.value) - 1)), old.expiresAt));
    }

    @Override
    public Optional<String> get(String key) {
        Entry e = data.get(key);
        if (e == null || e.expired()) {
            data.remove(key, e);
            return Optional.empty();
        }
        return Optional.of(e.value);
    }

    @Override
    public void set(String key, String value, Duration ttl) {
        data.put(key, new Entry(value, ttl == null ? null : Instant.now().plus(ttl)));
    }

    @Override
    public boolean setIfAbsent(String key, String value, Duration ttl) {
        boolean[] created = {false};
        data.compute(key, (k, old) -> {
            if (old == null || old.expired()) {
                created[0] = true;
                return new Entry(value, ttl == null ? null : Instant.now().plus(ttl));
            }
            return old;
        });
        return created[0];
    }

    @Override
    public void delete(String... keys) {
        for (String k : keys) {
            data.remove(k);
        }
    }
}
