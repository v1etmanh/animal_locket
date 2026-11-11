package notification_service_unit_test;

import com.animallocket.common.EventTypes;
import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.Events;
import com.animallocket.notification.DeviceDirectory;
import com.animallocket.notification.Notification;
import com.animallocket.notification.NotificationPlanner;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class NotificationPlannerUnitTest {
    private final NotificationPlanner planner = new NotificationPlanner(new DeviceDirectory() {
        @Override
        public List<String> tokens(String publicId) {
            return List.of();
        }

        @Override
        public List<String> friendIds(String publicId) {
            return List.of();
        }

        @Override
        public void removeToken(String token) {
        }
    });

    @Test
    void friendRequestNotifiesOnlyRecipientWithoutExposingSender() {
        var event = EventEnvelope.of(EventTypes.FRIEND_REQUEST_RECEIVED, "user-service", "recipient",
                new Events.FriendRequestReceived("private-sender-id", "recipient"));

        List<Notification> notifications = planner.plan(event);

        assertEquals(1, notifications.size());
        Notification notification = notifications.get(0);
        assertEquals("recipient", notification.recipientPublicId());
        assertEquals("FRIEND_REQUEST", notification.type());
        assertEquals("FRIEND_REQUEST", notification.data().get("type"));
        assertFalse((notification.title() + notification.body() + notification.data())
                .contains("private-sender-id"));
    }

    @Test
    void messageNotificationContainsConversationReferenceButNotMessageContent() {
        var event = EventEnvelope.of(EventTypes.MESSAGE_SENT, "chat-service", "recipient",
                new Events.MessageSent("conversation-1", "sender", "recipient"));

        Notification notification = planner.plan(event).get(0);

        assertEquals("recipient", notification.recipientPublicId());
        assertEquals("MESSAGE", notification.type());
        assertEquals(Map.of("conversationId", "conversation-1", "type", "MESSAGE"), notification.data());
        assertFalse((notification.title() + notification.body()).contains("sender"));
    }

    @Test
    void rejectedPhotoNotificationOnlyIncludesMediaReference() {
        var event = EventEnvelope.of(EventTypes.PHOTO_REJECTED, "media-service", "owner",
                new Events.PhotoRejected("media-1", "owner", "sensitive-detail", "POST", null));

        Notification notification = planner.plan(event).get(0);

        assertEquals("owner", notification.recipientPublicId());
        assertEquals("PHOTO_REJECTED", notification.type());
        assertEquals(Map.of("mediaId", "media-1", "type", "PHOTO_REJECTED"), notification.data());
        assertFalse((notification.title() + notification.body() + notification.data()).contains("sensitive-detail"));
    }
}
