package com.animallocket.user.repo;

import com.animallocket.user.domain.UserAvatar;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserAvatarRepository extends JpaRepository<UserAvatar, Long> {
    List<UserAvatar> findByPublicIdOrderByCreatedAtAsc(String publicId);

    /** Dùng để kiểm tra một avatar có thuộc bộ sưu tập của người này trước khi cho đổi sang nó. */
    Optional<UserAvatar> findByPublicIdAndAvatarKey(String publicId, String avatarKey);
}
