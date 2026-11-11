package post_service_integration_test;

import com.animallocket.common.EventTypes;
import com.animallocket.common.Headers;
import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.EventJson;
import com.animallocket.common.event.Events;
import com.animallocket.outbox.OutboxRepository;
import com.animallocket.post.PostServiceApplication;
import com.animallocket.post.client.UserDirectory;
import com.animallocket.post.domain.Post;
import com.animallocket.post.messaging.PostEventsListener;
import com.animallocket.post.repo.PostRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.mockito.Mockito.when;

@SpringBootTest(classes = PostServiceApplication.class)
@AutoConfigureMockMvc
class PostPublicationIntegrationTest {
    private static final String AUTHOR = "aaaaaaaaaaaaaaaaaaaa";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired PostRepository posts;
    @Autowired PostEventsListener listener;
    @Autowired OutboxRepository outbox;
    @MockBean UserDirectory users;
    @MockBean JwtDecoder jwtDecoder;

    @Test
    void photoReadyEventPublishesCreatedPostAndWritesOutboxEvent() throws Exception {
        String mediaId = UUID.randomUUID().toString();
        when(users.profiles(org.mockito.ArgumentMatchers.anySet())).thenReturn(java.util.Map.of());

        MvcResult created = mvc.perform(post("/api/v1/posts")
                        .header(Headers.PUBLIC_ID, AUTHOR)
                        .with(jwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mediaId\":\"" + mediaId + "\",\"caption\":\"integration\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode response = json.readTree(created.getResponse().getContentAsString());
        String postId = response.get("id").asText();

        EventEnvelope event = EventEnvelope.of(EventTypes.PHOTO_READY, "media-service", mediaId,
                new Events.PhotoReady(mediaId, AUTHOR, "public/" + mediaId, "NONE", 0, "POST", null));
        listener.onMessage(EventJson.write(event));

        Post persisted = posts.findById(postId).orElseThrow();
        assertEquals(Post.Status.PUBLISHED, persisted.getStatus());
        assertEquals("public/" + mediaId, persisted.getPublicKey());
        assertEquals(1, outbox.findAll().stream()
                .filter(outboxEvent -> EventTypes.POST_PUBLISHED.equals(outboxEvent.getType())
                        && postId.equals(outboxEvent.getKey()))
                .count());
    }
}
