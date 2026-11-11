package user_service_integration_test;

import com.animallocket.outbox.OutboxRepository;
import com.animallocket.user.UserServiceApplication;
import com.animallocket.user.domain.UserAccount;
import com.animallocket.user.repo.UserRepository;
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
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(classes = UserServiceApplication.class)
@AutoConfigureMockMvc
class UserRegistrationIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository users;
    @Autowired OutboxRepository outbox;
    @MockBean JwtDecoder jwtDecoder;

    @Test
    void registrationPersistsProfileAndPublishesUserRegisteredEvent() throws Exception {
        String sub = "integration-" + UUID.randomUUID();

        MvcResult result = mvc.perform(post("/api/v1/users/register")
                        .with(jwt().jwt(token -> token.subject(sub)))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"birthDate\":\"1995-01-01\"}"))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode profile = json.readTree(result.getResponse().getContentAsString());
        String publicId = profile.get("publicId").asText();
        UserAccount persisted = users.findByKeycloakSub(sub).orElseThrow();

        assertEquals(publicId, persisted.getPublicId());
        assertEquals(UserAccount.AgeGroup.ADULT, persisted.getAgeGroup());
        assertNotNull(persisted.getAvatarKey());
        assertNotEquals(sub, publicId);
        assertEquals(1, outbox.findAll().stream()
                .filter(event -> "USER_REGISTERED".equals(event.getType())
                        && publicId.equals(event.getKey()))
                .count());
    }
}
