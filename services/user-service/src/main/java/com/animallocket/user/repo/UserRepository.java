package com.animallocket.user.repo;

import com.animallocket.user.domain.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<UserAccount, Long> {
    Optional<UserAccount> findByPublicId(String publicId);

    Optional<UserAccount> findByKeycloakSub(String sub);

    List<UserAccount> findByPublicIdIn(Collection<String> publicIds);
}
