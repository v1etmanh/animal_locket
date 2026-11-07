package com.animallocket.post.repo;

import com.animallocket.post.domain.Post;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PostRepository extends JpaRepository<Post, String> {
    Optional<Post> findByMediaId(String mediaId);

    List<Post> findByAuthorIdInAndStatusAndPublishedAtLessThanOrderByPublishedAtDesc(
            Collection<String> authors, Post.Status status, Instant before, Pageable page);

    List<Post> findByAuthorIdAndStatusNotOrderByCreatedAtDesc(String authorId, Post.Status status, Pageable page);

    List<Post> findByAuthorId(String authorId);

    @Modifying
    @Query("update Post p set p.likeCount = p.likeCount + 1 where p.id = :id")
    void incLikes(String id);

    @Modifying
    @Query("update Post p set p.likeCount = case when p.likeCount > 0 then p.likeCount - 1 else 0 end where p.id = :id")
    void decLikes(String id);

    @Modifying
    @Query("update Post p set p.commentCount = p.commentCount + 1 where p.id = :id")
    void incComments(String id);

    @Modifying
    @Query("update Post p set p.commentCount = case when p.commentCount > 0 then p.commentCount - 1 else 0 end where p.id = :id")
    void decComments(String id);
}
