package com.animallocket.user;

import com.animallocket.common.EventTypes;
import com.animallocket.common.Headers;
import com.animallocket.common.event.EventEnvelope;
import com.animallocket.common.event.EventJson;
import com.animallocket.common.event.Events;
import com.animallocket.user.domain.AvatarSpinCredit;
import com.animallocket.user.domain.UserAvatar;
import com.animallocket.user.messaging.BillingEventsListener;
import com.animallocket.user.repo.AvatarSpinCreditRepository;
import com.animallocket.user.repo.UserAvatarRepository;
import com.animallocket.user.repo.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Lượt quay avatar mua được (docs/19-avatar-mechanism.md §8). */
@SpringBootTest
@AutoConfigureMockMvc
class AvatarSpinIntegrationTest {
    /** Chủ giả để chiếm kho trong test; trả lại ở @AfterEach để không ảnh hưởng test khác. */
    private static final String HOG = "spin-hog";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired BillingEventsListener billingEvents;
    @Autowired AvatarSpinCreditRepository credits;
    @Autowired UserAvatarRepository userAvatars;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;
    @MockBean JwtDecoder jwtDecoder;

    @AfterEach
    void releaseHoggedPool() {
        jdbc.update("UPDATE avatar_pool SET owner_public_id = NULL, assigned_at = NULL WHERE owner_public_id = ?", HOG);
    }

    private String register() throws Exception {
        MvcResult r = mvc.perform(post("/api/v1/users/register")
                        .with(jwt().jwt(j -> j.subject("sub-" + UUID.randomUUID())))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"birthDate\":\"1995-01-01\"}"))
                .andExpect(status().isCreated()).andReturn();
        return json.readTree(r.getResponse().getContentAsString()).get("publicId").asText();
    }

    private MockHttpServletRequestBuilder as(MockHttpServletRequestBuilder b, String publicId) {
        return b.header(Headers.PUBLIC_ID, publicId).with(jwt()).contentType(MediaType.APPLICATION_JSON);
    }

    /** Đưa một event CONSUMABLE_GRANTED vào listener như Kafka sẽ làm. {@code eventId} cố định để thử khử trùng. */
    private void deliverSpinGrant(String publicId, String eventId, int qty) {
        EventEnvelope e = new EventEnvelope(eventId, EventTypes.CONSUMABLE_GRANTED, 1, Instant.now(),
                "billing-service", null, publicId,
                EventJson.mapper().valueToTree(new Events.ConsumableGranted(publicId, "AVATAR_SPIN", qty)));
        billingEvents.onMessage(EventJson.write(e));
    }

    private int remaining(String publicId) {
        return credits.findById(publicId).map(AvatarSpinCredit::remaining).orElse(0);
    }

    /** Chiếm toàn bộ kho trừ {@code leave} avatar trống. */
    private void leaveOnlyFree(int leave) {
        List<String> free = jdbc.queryForList(
                "SELECT avatar_key FROM avatar_pool WHERE owner_public_id IS NULL ORDER BY avatar_key", String.class);
        for (String k : free.subList(0, free.size() - leave)) {
            jdbc.update("UPDATE avatar_pool SET owner_public_id = ? WHERE avatar_key = ?", HOG, k);
        }
    }

    @Test
    void spinAddsToCollectionWithoutChangingCurrentAvatar() throws Exception {
        String me = register();
        String before = users.findByPublicId(me).orElseThrow().avatarCode();
        deliverSpinGrant(me, UUID.randomUUID().toString(), 1);
        assertEquals(1, remaining(me));

        MvcResult r = mvc.perform(as(post("/api/v1/users/me/avatar/spin"), me))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.remaining").value(0)).andReturn();
        String won = json.readTree(r.getResponse().getContentAsString()).get("avatar").asText();

        assertNotEquals(before, won, "avatar quay được phải khác avatar đang có");
        // Vào bộ sưu tập với nguồn PURCHASE, nhưng avatar đang dùng KHÔNG đổi (quyết định: đổi là việc riêng).
        assertEquals(before, users.findByPublicId(me).orElseThrow().avatarCode(), "spin không được tự đổi avatar");
        List<UserAvatar> owned = userAvatars.findByPublicIdOrderByCreatedAtAsc(me);
        assertEquals(2, owned.size());
        // Không so theo thứ tự: hai bản ghi có thể cùng mốc thời gian. So theo nguồn và theo khoá đã quay được.
        assertTrue(owned.stream().anyMatch(a -> a.getSource() == UserAvatar.Source.PURCHASE));
        assertTrue(owned.stream().anyMatch(a -> won.endsWith(a.getAvatarKey())));
        mvc.perform(as(get("/api/v1/users/me/avatars"), me)).andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void spinWithoutCreditIsRejected() throws Exception {
        String me = register();
        mvc.perform(as(post("/api/v1/users/me/avatar/spin"), me))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NO_AVATAR_SPIN"));
        assertEquals(1, userAvatars.findByPublicIdOrderByCreatedAtAsc(me).size(), "không được cấp avatar nào");
    }

    @Test
    void sameEventIdNeverGrantsTwice() throws Exception {
        String me = register();
        String eventId = UUID.randomUUID().toString();
        deliverSpinGrant(me, eventId, 1);
        deliverSpinGrant(me, eventId, 1);
        assertEquals(1, remaining(me), "event phát lại không được cộng thêm lượt");

        deliverSpinGrant(me, UUID.randomUUID().toString(), 1);
        assertEquals(2, remaining(me), "event khác (kỳ sau) thì cộng thêm");
    }

    /**
     * Điểm then chốt của thiết kế: trừ lượt và cấp avatar nằm trong CÙNG transaction, nên kho cạn thì lượt
     * trở lại chứ người đã trả tiền không mất gì.
     */
    @Test
    void exhaustedPoolDoesNotConsumeCredit() throws Exception {
        String me = register();
        deliverSpinGrant(me, UUID.randomUUID().toString(), 1);
        leaveOnlyFree(0);

        mvc.perform(as(post("/api/v1/users/me/avatar/spin"), me))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("AVATAR_POOL_EXHAUSTED"));

        assertEquals(1, remaining(me), "cấp avatar thất bại thì lượt quay phải được hoàn lại");
        assertEquals(1, userAvatars.findByPublicIdOrderByCreatedAtAsc(me).size());
    }

    @Test
    void concurrentSpinsCannotExceedCredits() throws Exception {
        String me = register();
        deliverSpinGrant(me, UUID.randomUUID().toString(), 2);

        ExecutorService exec = Executors.newFixedThreadPool(4);
        List<Future<MvcResult>> fs = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            fs.add(exec.submit(() -> mvc.perform(as(post("/api/v1/users/me/avatar/spin"), me)).andReturn()));
        }
        int ok = 0;
        Set<String> won = new HashSet<>();
        for (Future<MvcResult> f : fs) {
            MvcResult r = f.get();
            if (r.getResponse().getStatus() == 200) {
                ok++;
                won.add(json.readTree(r.getResponse().getContentAsString()).get("avatar").asText());
            } else {
                // 409 = hết lượt (trường hợp mong đợi); 503 = AVATAR_BUSY khi hai bên giành cùng avatar trong kho.
                assertTrue(List.of(409, 503).contains(r.getResponse().getStatus()),
                        r.getResponse().getStatus() + " " + r.getResponse().getContentAsString());
            }
        }
        exec.shutdown();
        assertEquals(2, ok, "chỉ hai lượt được dùng");
        assertEquals(2, won.size(), "hai lượt phải ra hai avatar khác nhau");
        assertEquals(0, remaining(me));
    }

    @Test
    void switchAvatarOnlyAcceptsOwnedAvatars() throws Exception {
        String me = register();
        String other = register();
        String mine = users.findByPublicId(me).orElseThrow().avatarCode();
        String theirs = users.findByPublicId(other).orElseThrow().avatarCode();

        // Avatar của người khác: từ chối, và avatar đang dùng không đổi.
        mvc.perform(as(put("/api/v1/users/me/avatar"), me).content("{\"avatar\":\"" + theirs + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("AVATAR_NOT_OWNED"));
        assertEquals(mine, users.findByPublicId(me).orElseThrow().avatarCode());

        // Quay thêm một cái rồi đổi sang nó.
        deliverSpinGrant(me, UUID.randomUUID().toString(), 1);
        MvcResult spun = mvc.perform(as(post("/api/v1/users/me/avatar/spin"), me)).andExpect(status().isOk()).andReturn();
        String won = json.readTree(spun.getResponse().getContentAsString()).get("avatar").asText();

        mvc.perform(as(put("/api/v1/users/me/avatar"), me).content("{\"avatar\":\"" + won + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatar").value(won));
        assertEquals(won, users.findByPublicId(me).orElseThrow().avatarCode());

        // Đổi lại avatar cũ vẫn được: avatar cũ vẫn thuộc người này trong kho (docs/19 §4.3).
        mvc.perform(as(put("/api/v1/users/me/avatar"), me).content("{\"avatar\":\"" + mine + "\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.avatar").value(mine));
        // Gọi lại với avatar đang dùng: không lỗi, không đổi gì.
        mvc.perform(as(put("/api/v1/users/me/avatar"), me).content("{\"avatar\":\"" + mine + "\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.avatar").value(mine));
    }

    @Test
    void meExposesRemainingSpins() throws Exception {
        String me = register();
        mvc.perform(as(get("/api/v1/users/me"), me)).andExpect(jsonPath("$.avatarSpins").value(0));
        deliverSpinGrant(me, UUID.randomUUID().toString(), 1);
        mvc.perform(as(get("/api/v1/users/me"), me)).andExpect(jsonPath("$.avatarSpins").value(1));
        mvc.perform(as(post("/api/v1/users/me/avatar/spin"), me)).andExpect(status().isOk());
        mvc.perform(as(get("/api/v1/users/me"), me)).andExpect(jsonPath("$.avatarSpins").value(0));
    }

    @Test
    void grantForUnknownUserIsIgnored() {
        String ghost = "zzzzzzzzzzzzzzzzzzzz";
        deliverSpinGrant(ghost, UUID.randomUUID().toString(), 1);
        assertFalse(credits.findById(ghost).isPresent(), "không tạo số dư cho tài khoản không tồn tại");
    }

    @Test
    void deletingAccountRemovesSpinCredits() throws Exception {
        String me = register();
        deliverSpinGrant(me, UUID.randomUUID().toString(), 1);
        assertTrue(credits.findById(me).isPresent());
        mvc.perform(as(delete("/api/v1/users/me"), me)).andExpect(status().isNoContent());
        assertFalse(credits.findById(me).isPresent());
    }
}
