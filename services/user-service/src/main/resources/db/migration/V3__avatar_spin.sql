-- Lượt quay avatar mua được (docs/19-avatar-mechanism.md §8).
-- Số dư nằm ở đây, KHÔNG ở ví của billing-service: như vậy việc trừ lượt và việc cấp avatar từ avatar_pool
-- nằm trong cùng một transaction, nên không thể mất lượt (cấp avatar lỗi thì lượt rollback) cũng không thể
-- quay nhiều hơn số lượt đã mua. billing-service vẫn là nguồn sự thật về tiền và giữ sổ cái.
--
-- Chỉ cộng/trừ bằng UPDATE có điều kiện, không đọc-rồi-ghi: used < granted là chỗ chặn cứng.

CREATE TABLE avatar_spin_credit (
    public_id VARCHAR(20) NOT NULL,
    granted INT NOT NULL DEFAULT 0,           -- tổng số lượt đã được cấp, chỉ tăng
    used INT NOT NULL DEFAULT 0,              -- số lượt đã quay, chỉ tăng; còn lại = granted - used
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (public_id),
    CONSTRAINT ck_spin_used CHECK (used <= granted)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
