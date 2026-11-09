package user_service_unit_test;

import com.animallocket.common.web.ApiException;
import com.animallocket.outbox.OutboxService;
import com.animallocket.user.domain.FriendRequest;
import com.animallocket.user.domain.Friendship;
import com.animallocket.user.domain.Report;
import com.animallocket.user.domain.UserAccount;
import com.animallocket.user.dto.Dtos;
import com.animallocket.user.repo.BlockRepository;
import com.animallocket.user.repo.DeviceTokenRepository;
import com.animallocket.user.repo.FriendRequestRepository;
import com.animallocket.user.repo.FriendshipRepository;
import com.animallocket.user.repo.ReportRepository;
import com.animallocket.user.repo.UserRepository;
import com.animallocket.user.service.SafetyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SafetyServiceTest {
    @Mock UserRepository users;
    @Mock BlockRepository blocks;
    @Mock FriendshipRepository friendships;
    @Mock FriendRequestRepository requests;
    @Mock ReportRepository reports;
    @Mock DeviceTokenRepository devices;
    @Mock OutboxService outbox;

    private SafetyService service;

    @BeforeEach
    void setUp() {
        service = new SafetyService(users, blocks, friendships, requests, reports, devices, outbox);
    }

    @Test
    void blockingYourselfIsRejectedBeforeDatabaseAccess() {
        ApiException error = assertThrows(ApiException.class, () -> service.block("user", "user"));

        assertEquals("SELF_BLOCK", error.code());
        verifyNoInteractions(users, blocks, friendships, requests, outbox);
    }

    @Test
    void blockRemovesFriendshipCancelsBothPendingRequestsAndPublishesEvent() {
        UserAccount target = new UserAccount();
        target.setStatus(UserAccount.Status.ACTIVE);
        FriendRequest outgoing = new FriendRequest("me", "target", FriendRequest.Source.SWIPE);
        FriendRequest incoming = new FriendRequest("target", "me", FriendRequest.Source.INVITE);
        Friendship friendship = new Friendship("me", "target");
        when(users.findByPublicId("target")).thenReturn(Optional.of(target));
        when(blocks.existsByBlockerIdAndBlockedId("me", "target")).thenReturn(false);
        when(friendships.findByUserLowAndUserHigh("me", "target")).thenReturn(Optional.of(friendship));
        when(requests.findByFromIdAndToId("me", "target")).thenReturn(Optional.of(outgoing));
        when(requests.findByFromIdAndToId("target", "me")).thenReturn(Optional.of(incoming));

        service.block("me", "target");

        verify(blocks).save(any());
        verify(friendships).delete(friendship);
        assertEquals(FriendRequest.Status.CANCELED, outgoing.getStatus());
        assertEquals(FriendRequest.Status.CANCELED, incoming.getStatus());
        verify(outbox).publish(anyString(), anyString(), anyString(), any());
    }

    @Test
    void existingBlockIsIdempotent() {
        UserAccount target = new UserAccount();
        target.setStatus(UserAccount.Status.ACTIVE);
        when(users.findByPublicId("target")).thenReturn(Optional.of(target));
        when(blocks.existsByBlockerIdAndBlockedId("me", "target")).thenReturn(true);

        service.block("me", "target");

        verify(blocks, never()).save(any());
        verifyNoInteractions(friendships, requests, outbox);
    }

    @Test
    void reportLimitRejectsTheNextReport() {
        when(reports.countByReporterIdAndCreatedAtGreaterThanEqual(anyString(), any()))
                .thenReturn(20L);
        Dtos.ReportRequest request = new Dtos.ReportRequest(
                Report.TargetType.USER, "target", null, "SPAM", null);

        ApiException error = assertThrows(ApiException.class, () -> service.report("me", request));

        assertEquals("REPORT_LIMIT", error.code());
        verify(reports, never()).save(any());
    }
}
