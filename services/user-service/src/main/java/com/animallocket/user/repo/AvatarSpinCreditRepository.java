package com.animallocket.user.repo;

import com.animallocket.user.domain.AvatarSpinCredit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;

public interface AvatarSpinCreditRepository extends JpaRepository<AvatarSpinCredit, String> {
    /** Cộng lượt nguyên tử. Trả 0 khi người này chưa có dòng nào (người gọi tự chèn). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update AvatarSpinCredit c set c.granted = c.granted + :qty, c.updatedAt = :now where c.publicId = :id")
    int addGranted(@Param("id") String publicId, @Param("qty") int qty, @Param("now") Instant now);

    /**
     * Tiêu một lượt nguyên tử: chỉ thành công (trả 1) khi còn lượt. Đây là chỗ chặn cứng, không đọc-rồi-ghi,
     * nên hai yêu cầu quay cùng lúc với số dư 1 thì chỉ một bên đi tiếp.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update AvatarSpinCredit c set c.used = c.used + 1, c.updatedAt = :now "
            + "where c.publicId = :id and c.used < c.granted")
    int useOne(@Param("id") String publicId, @Param("now") Instant now);

    @Modifying
    @Query("delete from AvatarSpinCredit c where c.publicId = :id")
    void deleteAllOf(@Param("id") String publicId);
}
