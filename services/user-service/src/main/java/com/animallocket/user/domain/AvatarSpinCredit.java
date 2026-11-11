package com.animallocket.user.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Số lượt quay avatar của một người (docs/19-avatar-mechanism.md §8).
 *
 * <p>Hai bộ đếm chỉ tăng thay vì một số dư: số còn lại là {@code granted - used}. Nhờ vậy mọi thay đổi đều là
 * {@code UPDATE ... SET x = x + 1} có điều kiện, không bao giờ đọc-rồi-ghi, và vẫn tra được đã cấp/đã dùng bao nhiêu.
 */
@Entity
@Table(name = "avatar_spin_credit")
@Getter
@NoArgsConstructor
public class AvatarSpinCredit {
    @Id
    @Column(name = "public_id", nullable = false, length = 20)
    private String publicId;
    @Column(nullable = false)
    private int granted;
    @Column(nullable = false)
    private int used;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public AvatarSpinCredit(String publicId, int granted) {
        this.publicId = publicId;
        this.granted = granted;
    }

    public int remaining() {
        return granted - used;
    }
}
