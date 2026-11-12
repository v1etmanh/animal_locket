package com.animallocket.notification;

import com.animallocket.common.EventTypes;
import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.EventJson;
import com.animallocket.common.event.Events;
import com.google.firebase.messaging.MessagingErrorCode;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.oauth2.jwt.JwtDecoder;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class NotificationTest {
    @Autowired LoggingPushSender loggingSender;
    @MockBean JwtDecoder jwtDecoder;
    @MockBean DeviceDirectory contextDirectory;

    static class FakeDirectory implements DeviceDirectory {
        final Map<String, List<String>> tokens;
        final Map<String, List<String>> friends;
        final List<String> removed = new ArrayList<>();
        boolean failTokens;

        FakeDirectory(Map<String, List<String>> tokens, Map<String, List<String>> friends) {
            this.tokens = tokens;
            this.friends = friends;
        }

        public List<String> tokens(String id) {
            if (failTokens) {
                throw new IllegalStateException("user-service down");
            }
            return tokens.getOrDefault(id, List.of());
        }

        public List<String> friendIds(String id) {
            return friends.getOrDefault(id, List.of());
        }

        public void removeToken(String token) {
            removed.add(token);
        }
    }

    static class ScriptedSender implements PushSender {
        final List<Result> script;
        final List<String> sentTo = new ArrayList<>();
        int calls;

        ScriptedSender(Result... script) {
            this.script = List.of(script);
        }

        public Result send(String token, String title, String body, Map<String, String> data) {
            sentTo.add(token);
            return script.get(Math.min(calls++, script.size() - 1));
        }
    }

    private NotificationDispatcher dispatcher(DeviceDirectory dir, PushSender sender, List<Long> sleeps) {
        NotificationDispatcher d = new NotificationDispatcher(dir, sender, new SimpleMeterRegistry(), 3, 100);
        d.setSleeper(sleeps::add);
        return d;
    }

    private EventEnvelope env(String type, Object payload) {
        return EventEnvelope.of(type, "test", "k", payload);
    }

    @Test
    void contextLoadsWithLoggingSenderWhenFcmNotConfigured() {
        assertTrue(loggingSender != null);
    }

    @Test
    void newPostFansOutToEveryFriendButNotAuthor() {
        var dir = new FakeDirectory(Map.of(), Map.of("author", List.of("f1", "f2", "f3")));
        var planner = new NotificationPlanner(dir);
        var out = planner.plan(env(EventTypes.POST_PUBLISHED, new Events.PostPublished("p1", "author")));
        assertEquals(List.of("f1", "f2", "f3"), out.stream().map(Notification::recipientPublicId).toList());
        assertEquals("p1", out.get(0).data().get("postId"));
    }

    @Test
    void friendAcceptedNotifiesBothSides() {
        var planner = new NotificationPlanner(new FakeDirectory(Map.of(), Map.of()));
        var out = planner.plan(env(EventTypes.FRIEND_ACCEPTED, new Events.FriendAccepted("a", "b")));
        assertEquals(List.of("a", "b"), out.stream().map(Notification::recipientPublicId).toList());
    }

    @Test
    void notificationTextNeverContainsIdentities() {
        var planner = new NotificationPlanner(new FakeDirectory(Map.of(), Map.of()));
        var out = planner.plan(env(EventTypes.POST_LIKED, new Events.PostLiked("p1", "authorId", "likerSecretId")));
        Notification n = out.get(0);
        assertFalse((n.title() + n.body() + n.data()).contains("likerSecretId"));
        assertEquals("authorId", n.recipientPublicId());
    }

    @Test
    void unknownEventsProduceNothing() {
        var planner = new NotificationPlanner(new FakeDirectory(Map.of(), Map.of()));
        assertTrue(planner.plan(env(EventTypes.USER_BLOCKED, new Events.UserBlocked("a", "b"))).isEmpty());
    }

    @Test
    void transientErrorsRetryWithBackoffThenSucceed() {
        var dir = new FakeDirectory(Map.of("u", List.of("tok1")), Map.of());
        var sender = new ScriptedSender(PushSender.Result.TRANSIENT_ERROR, PushSender.Result.TRANSIENT_ERROR, PushSender.Result.OK);
        List<Long> sleeps = new ArrayList<>();
        dispatcher(dir, sender, sleeps).dispatch(new Notification("u", "T", "t", "b", Map.of()));
        assertEquals(3, sender.calls);
        assertEquals(List.of(100L, 200L), sleeps);
    }

    @Test
    void persistentFailureIsDroppedAfterMaxAttempts() {
        var dir = new FakeDirectory(Map.of("u", List.of("tok1")), Map.of());
        var sender = new ScriptedSender(PushSender.Result.TRANSIENT_ERROR);
        dispatcher(dir, sender, new ArrayList<>()).dispatch(new Notification("u", "T", "t", "b", Map.of()));
        assertEquals(3, sender.calls); // dừng, không ném lỗi, không vòng lặp vô hạn
    }

    @Test
    void invalidTokenIsRemovedWithoutRetry() {
        var dir = new FakeDirectory(Map.of("u", List.of("dead", "alive")), Map.of());
        var sender = new ScriptedSender(PushSender.Result.INVALID_TOKEN, PushSender.Result.OK);
        dispatcher(dir, sender, new ArrayList<>()).dispatch(new Notification("u", "T", "t", "b", Map.of()));
        assertEquals(List.of("dead"), dir.removed);
        assertEquals(List.of("dead", "alive"), sender.sentTo);
    }

    @Test
    void configurationAndPayloadErrorsNeverInvalidateDeviceTokens() {
        assertEquals(PushSender.Result.INVALID_TOKEN, FcmPushSender.classify(MessagingErrorCode.UNREGISTERED));
        for (var code : List.of(MessagingErrorCode.SENDER_ID_MISMATCH,
                MessagingErrorCode.INVALID_ARGUMENT, MessagingErrorCode.THIRD_PARTY_AUTH_ERROR)) {
            assertEquals(PushSender.Result.PERMANENT_ERROR, FcmPushSender.classify(code));
        }
        assertEquals(PushSender.Result.TRANSIENT_ERROR, FcmPushSender.classify(MessagingErrorCode.UNAVAILABLE));
        assertEquals(PushSender.Result.TRANSIENT_ERROR, FcmPushSender.classify(MessagingErrorCode.INTERNAL));
        assertEquals(PushSender.Result.TRANSIENT_ERROR, FcmPushSender.classify(MessagingErrorCode.QUOTA_EXCEEDED));
    }

    @Test
    void permanentErrorsDoNotRetryOrDeleteTokens() {
        var dir = new FakeDirectory(Map.of("u", List.of("valid")), Map.of());
        var sender = new ScriptedSender(PushSender.Result.PERMANENT_ERROR);
        List<Long> sleeps = new ArrayList<>();
        dispatcher(dir, sender, sleeps).dispatch(new Notification("u", "T", "t", "b", Map.of()));
        assertEquals(1, sender.calls);
        assertTrue(dir.removed.isEmpty());
        assertTrue(sleeps.isEmpty());
    }

    @Test
    void directoryFailureIsSwallowed() {
        var dir = new FakeDirectory(Map.of("u", List.of("tok")), Map.of());
        dir.failTokens = true;
        var sender = new ScriptedSender(PushSender.Result.OK);
        dispatcher(dir, sender, new ArrayList<>()).dispatch(new Notification("u", "T", "t", "b", Map.of()));
        assertEquals(0, sender.calls);
    }

    @Test
    void listenerDeduplicatesAndSurvivesGarbage() {
        var dir = new FakeDirectory(Map.of("owner", List.of("tok")), Map.of());
        var sender = new ScriptedSender(PushSender.Result.OK);
        Executor direct = Runnable::run;
        var listener = new NotificationListener(new NotificationPlanner(dir),
                dispatcher(dir, sender, new ArrayList<>()), direct);

        String wire = EventJson.write(env(EventTypes.POST_LIKED, new Events.PostLiked("p", "owner", "x")));
        listener.onMessage(wire);
        listener.onMessage(wire);           // cùng eventId → bỏ qua
        listener.onMessage("{{ garbage");   // không ném lỗi
        assertEquals(1, sender.calls);
    }
}
