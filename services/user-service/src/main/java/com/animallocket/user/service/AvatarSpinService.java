package com.animallocket.user.service;

import com.animallocket.common.web.ApiException;
import com.animallocket.user.domain.AvatarSpinCredit;
import com.animallocket.user.domain.UserAccount;
import com.animallocket.user.domain.UserAvatar;
import com.animallocket.user.dto.Dtos;
import com.animallocket.user.repo.AvatarSpinCreditRepository;
import com.animallocket.user.repo.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Lượt quay avatar mua được (docs/19-avatar-mechanism.md §8).
 *
 * <p>Lượt được cấp từ event {@code CONSUMABLE_GRANTED} của billing-service (một lượt cho mỗi kỳ thuê bao), và
 * được tiêu ở {@link #spin(String)} <b>trong cùng transaction</b> với {@link AvatarAllocator}: kho cạn thì
 * transaction rollback và lượt trở lại, nên người đã trả tiền không bao giờ mất lượt vì lỗi phía server.
 */
@Service
public class AvatarSpinService {
    private final AvatarSpinCreditRepository credits;
    private final AvatarAllocator allocator;
    private final UserRepository users;

    public AvatarSpinService(AvatarSpinCreditRepository credits, AvatarAllocator allocator, UserRepository users) {
        this.credits = credits;
        this.allocator = allocator;
        this.users = users;
    }

    /**
     * Cộng lượt cho một người. Chống trùng là việc của người gọi (listener dùng {@code idempotency.firstTime}),
     * ở đây chỉ cần cộng nguyên tử.
     */
    @Transactional
    public void grant(String publicId, int qty) {
        if (qty <= 0) {
            return;
        }
        if (users.findByPublicId(publicId).filter(UserAccount::isActive).isEmpty()) {
            return; // tài khoản không còn hoạt động: bỏ qua, giống grantPack
        }
        if (credits.addGranted(publicId, qty, Instant.now()) == 0) {
            credits.save(new AvatarSpinCredit(publicId, qty));
        }
    }

    @Transactional(readOnly = true)
    public int remaining(String publicId) {
        return credits.findById(publicId).map(AvatarSpinCredit::remaining).orElse(0);
    }

    /** Quay một avatar mới từ kho chung; avatar vào bộ sưu tập, KHÔNG tự thay avatar đang dùng. */
    @Transactional
    public Dtos.AvatarSpinResult spin(String publicId) {
        users.findByPublicId(publicId).filter(UserAccount::isActive)
                .orElseThrow(() -> ApiException.notFound("Người dùng"));
        if (credits.useOne(publicId, Instant.now()) != 1) {
            throw new ApiException(HttpStatus.CONFLICT, "NO_AVATAR_SPIN",
                    "Bạn không còn lượt quay avatar nào");
        }
        AvatarLibrary.Avatar avatar = allocator.allocate(publicId, UserAvatar.Source.PURCHASE);
        // Đọc lại trong cùng transaction (useOne đã clear persistence context), không gọi remaining() qua this.
        int left = credits.findById(publicId).map(AvatarSpinCredit::remaining).orElse(0);
        return new Dtos.AvatarSpinResult(avatar.code(), left);
    }
}
