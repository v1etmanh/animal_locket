package com.animallocket.common;

import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.EventJson;
import com.animallocket.common.event.Events;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PublicIdsTest {

    @Test
    void generatedIdsAreValidAndUnique() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 5000; i++) {
            String id = PublicIds.generate();
            assertTrue(PublicIds.isValid(id), id);
            assertTrue(seen.add(id), "trùng id " + id);
        }
    }

    @Test
    void rejectsMalformedIds() {
        assertFalse(PublicIds.isValid(null));
        assertFalse(PublicIds.isValid(""));
        assertFalse(PublicIds.isValid("UPPERCASEUPPERCASE12"));
        assertFalse(PublicIds.isValid("short"));
        assertFalse(PublicIds.isValid("0000000000000000000a"));
    }

    @Test
    void envelopeRoundTrip() {
        var env = EventEnvelope.of(EventTypes.USER_BLOCKED, "user-service", "k1",
                new Events.UserBlocked("a", "b"));
        var back = EventJson.read(EventJson.write(env));
        assertEquals(env.eventId(), back.eventId());
        assertEquals("a", back.payloadAs(Events.UserBlocked.class).blockerPublicId());
    }
}
