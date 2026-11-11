package notification_service_integration_test;

import com.animallocket.common.EventTypes;
import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.EventJson;
import com.animallocket.common.event.Events;
import com.animallocket.notification.DeviceDirectory;
import com.animallocket.notification.NotificationListener;
import com.animallocket.notification.NotificationServiceApplication;
import com.animallocket.notification.PushSender;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.oauth2.jwt.JwtDecoder;

import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@SpringBootTest(classes = NotificationServiceApplication.class)
class NotificationDeliveryIntegrationTest {
    @Autowired NotificationListener listener;
    @MockBean DeviceDirectory directory;
    @MockBean PushSender sender;
    @MockBean JwtDecoder jwtDecoder;

    @Test
    void serializedMessageEventIsDeliveredOnceDespiteDuplicateEvent() {
        when(directory.tokens("recipient")).thenReturn(List.of("device-token"));
        when(sender.send("device-token", "Tin nhắn mới", "Bạn có tin nhắn mới",
                Map.of("conversationId", "conversation-1", "type", "MESSAGE")))
                .thenReturn(PushSender.Result.OK);
        String wireEvent = EventJson.write(EventEnvelope.of(EventTypes.MESSAGE_SENT, "chat-service", "recipient",
                new Events.MessageSent("conversation-1", "sender", "recipient")));

        listener.onMessage(wireEvent);
        listener.onMessage(wireEvent);

        verify(sender, timeout(TimeUnit.SECONDS.toMillis(5)).times(1)).send(
                "device-token", "Tin nhắn mới", "Bạn có tin nhắn mới",
                Map.of("conversationId", "conversation-1", "type", "MESSAGE"));
    }
}
