package com.animallocket.common.kv;

import java.time.Duration;
import java.util.Optional;

/**
 * Kho key-value có TTL, dùng cho hạn mức, cache bạn bè, bản sao quyền lợi.
 * Cài đặt Redis cho runtime; cài đặt bộ nhớ cho test và dev không có Redis.
 */
public interface KeyValueStore {

    /** Tăng bộ đếm; nếu key mới tạo thì đặt TTL. Trả về giá trị sau khi tăng. */
    long increment(String key, Duration ttlIfNew);

    /** Giảm bộ đếm (hoàn hạn mức khi thao tác thất bại). Không đi dưới 0. */
    void decrement(String key);

    Optional<String> get(String key);

    void set(String key, String value, Duration ttl);

    boolean setIfAbsent(String key, String value, Duration ttl);

    void delete(String... keys);
}
