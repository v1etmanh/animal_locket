package com.animallocket.common;

import com.animallocket.common.kv.InMemoryKeyValueStore;
import com.animallocket.common.kv.KeyValueStore;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class KeyValueStoreTest {
    KeyValueStore kv = new InMemoryKeyValueStore();

    @Test
    void incrementCountsAndDecrementFloorsAtZero() {
        assertEquals(1, kv.increment("q", Duration.ofMinutes(1)));
        assertEquals(2, kv.increment("q", Duration.ofMinutes(1)));
        kv.decrement("q");
        assertEquals("1", kv.get("q").orElseThrow());
        kv.decrement("q");
        kv.decrement("q");
        assertEquals("0", kv.get("q").orElseThrow());
    }

    @Test
    void expiredKeysDisappearAndRestartCounters() throws Exception {
        kv.set("k", "v", Duration.ofMillis(30));
        assertTrue(kv.get("k").isPresent());
        Thread.sleep(60);
        assertTrue(kv.get("k").isEmpty());
        kv.increment("c", Duration.ofMillis(30));
        Thread.sleep(60);
        assertEquals(1, kv.increment("c", Duration.ofMinutes(1)));
    }

    @Test
    void setIfAbsentOnlyFirstWins() {
        assertTrue(kv.setIfAbsent("lock", "a", Duration.ofMinutes(1)));
        assertFalse(kv.setIfAbsent("lock", "b", Duration.ofMinutes(1)));
        assertEquals("a", kv.get("lock").orElseThrow());
        kv.delete("lock");
        assertTrue(kv.setIfAbsent("lock", "c", Duration.ofMinutes(1)));
    }
}
