package post_service_unit_test;

import com.animallocket.common.EventTypes;
import com.animallocket.common.Topics;
import com.animallocket.common.event.Events;
import com.animallocket.common.web.ApiException;
import com.animallocket.outbox.OutboxService;
import com.animallocket.post.client.UserDirectory;
import com.animallocket.post.domain.MediaState;
import com.animallocket.post.domain.Post;
import com.animallocket.post.repo.CommentRepository;
import com.animallocket.post.repo.MediaStateRepository;
import com.animallocket.post.repo.PostLikeRepository;
import com.animallocket.post.repo.PostRepository;
import com.animallocket.post.service.QuotaService;
import com.animallocket.post.service.PostService;
import com.animallocket.post.dto.PostDtos;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PostServiceTest {
    @Mock PostRepository posts;
    @Mock PostLikeRepository likes;
    @Mock CommentRepository comments;
    @Mock MediaStateRepository mediaStates;
    @Mock UserDirectory users;
    @Mock QuotaService quota;
    @Mock OutboxService outbox;

    private PostService service;

    @BeforeEach
    void setUp() {
        service = new PostService(posts, likes, comments, mediaStates, users, quota, outbox);
    }

    @Test
    void createIsIdempotentForTheSameOwnerAndMedia() {
        Post existing = post("post-1", "owner", "media-1", Post.Status.PUBLISHED);
        existing.setCaption("already posted");
        when(posts.findByMediaId("media-1")).thenReturn(Optional.of(existing));

        PostDtos.PostView view = service.create("owner",
                new PostDtos.CreatePostRequest("media-1", "ignored"));

        assertEquals("post-1", view.id());
        assertEquals("already posted", view.caption());
        assertEquals(Post.Status.PUBLISHED, view.status());
        verifyNoInteractions(quota, mediaStates, outbox);
        verify(posts, never()).save(any());
    }

    @Test
    void createRejectsMediaOwnedByAnotherUser() {
        Post existing = post("post-1", "owner", "media-1", Post.Status.PENDING_MEDIA);
        when(posts.findByMediaId("media-1")).thenReturn(Optional.of(existing));

        ApiException error = assertThrows(ApiException.class, () -> service.create("other",
                new PostDtos.CreatePostRequest("media-1", null)));

        assertEquals(403, error.status().value());
        verifyNoInteractions(quota, mediaStates, outbox);
    }

    @Test
    void createWithReadyMediaPublishesImmediatelyAndNormalizesCaption() {
        MediaState ready = new MediaState("media-1", "owner", "READY", "public/key", null);
        when(posts.findByMediaId("media-1")).thenReturn(Optional.empty());
        when(mediaStates.findById("media-1")).thenReturn(Optional.of(ready));
        when(posts.save(any(Post.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PostDtos.PostView view = service.create("owner",
                new PostDtos.CreatePostRequest("media-1", "  hello  "));

        assertEquals(Post.Status.PUBLISHED, view.status());
        assertEquals("hello", view.caption());
        assertNotNull(view.publishedAt());
        ArgumentCaptor<Post> saved = ArgumentCaptor.forClass(Post.class);
        verify(posts).save(saved.capture());
        assertEquals("public/key", saved.getValue().getPublicKey());
        verify(quota).consume("owner");
        verify(outbox).publish(eq(Topics.POST), eq(EventTypes.POST_PUBLISHED),
                eq(saved.getValue().getId()), any(Events.PostPublished.class));
    }

    @Test
    void rejectedPhotoMovesPendingPostToRejectedAndRefundsQuota() {
        Instant createdAt = Instant.parse("2026-01-02T03:04:05Z");
        Post pending = post("post-1", "owner", "media-1", Post.Status.PENDING_MEDIA);
        pending.setCreatedAt(createdAt);
        when(mediaStates.save(any(MediaState.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(posts.findForUpdateByMediaId("media-1")).thenReturn(Optional.of(pending));

        service.onPhotoRejected(new Events.PhotoRejected(
                "media-1", "owner", "PROCESSING_TIMEOUT", "POST", null));

        assertEquals(Post.Status.REJECTED, pending.getStatus());
        assertEquals("PROCESSING_TIMEOUT", pending.getRejectReason());
        verify(quota).refund("owner", createdAt);
        verify(outbox, never()).publish(anyString(), anyString(), anyString(), any());
    }

    private static Post post(String id, String owner, String mediaId, Post.Status status) {
        Post post = new Post();
        post.setId(id);
        post.setAuthorId(owner);
        post.setMediaId(mediaId);
        post.setStatus(status);
        return post;
    }
}
