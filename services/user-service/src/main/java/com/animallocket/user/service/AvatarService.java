package com.animallocket.user.service;

import com.animallocket.common.EventTypes;
import com.animallocket.common.Topics;
import com.animallocket.common.event.Events;
import com.animallocket.common.web.ApiException;
import com.animallocket.outbox.OutboxService;
import com.animallocket.user.domain.UserAccount;
import com.animallocket.user.domain.UserAvatar;
import com.animallocket.user.dto.Dtos;
import com.animallocket.user.repo.UserAvatarRepository;
import com.animallocket.user.repo.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AvatarService {
    private final UserRepository users;
    private final UserAvatarRepository userAvatars;
    private final AvatarAllocator allocator;
    private final OutboxService outbox;
    private final AccountService accounts;

    public AvatarService(UserRepository users, UserAvatarRepository userAvatars, AvatarAllocator allocator,
                         OutboxService outbox, AccountService accounts) {
        this.users = users;
        this.userAvatars = userAvatars;
        this.allocator = allocator;
        this.outbox = outbox;
        this.accounts = accounts;
    }

    /**
     * Cấp avatar ngẫu nhiên cho tài khoản cũ chưa có. Idempotent: người đã có avatar thì không làm gì (false).
     * Mỗi người một transaction để một lỗi không làm hỏng cả đợt.
     */
    @Transactional
    public boolean assignToExisting(String publicId) {
        if (users.findByPublicId(publicId).map(u -> u.getAvatarKey() != null).orElse(true)) {
            return false;
        }
        AvatarLibrary.Avatar a = allocator.allocate(publicId, UserAvatar.Source.BACKFILL);
        if (users.assignAvatarIfMissing(publicId, a.key(), a.version(), a.animal()) != 1) {
            // Instance khác vừa gán xong: huỷ cả transaction để avatar vừa giữ trở về kho.
            throw new IllegalStateException("Avatar của " + publicId + " vừa được gán ở nơi khác");
        }
        outbox.publish(Topics.USER, EventTypes.AVATAR_CHANGED, publicId,
                new Events.AvatarChanged(publicId, a.code(), a.animal()));
        outbox.publish(Topics.USER, EventTypes.LEAD_ANIMAL_CHANGED, publicId,
                new Events.LeadAnimalChanged(publicId, a.animal()));
        return true;
    }

    /**
     * Đổi avatar đang dùng sang một avatar đã có trong bộ sưu tập (docs/19 §4.3).
     *
     * <p>Chỉ nhận avatar mà chính người này đang sở hữu trong {@code user_avatars}; phiên bản thư viện lấy từ bản
     * ghi đã lưu, không tin phần phiên bản trong mã do client gửi. Avatar cũ vẫn thuộc người này trong
     * {@code avatar_pool}, nên không ai khác quay ra được (§4.3) và đổi qua lại bao nhiêu lần cũng được.
     *
     * @param code mã avatar dạng "v:animal:palette:accessory" như {@code GET /users/me/avatars} trả về
     */
    @Transactional
    public Dtos.MeProfile switchTo(String publicId, String code) {
        UserAccount user = users.findByPublicId(publicId).filter(UserAccount::isActive)
                .orElseThrow(() -> ApiException.notFound("Người dùng"));
        String key = keyOf(code);
        UserAvatar owned = userAvatars.findByPublicIdAndAvatarKey(publicId, key)
                .orElseThrow(() -> ApiException.badRequest("AVATAR_NOT_OWNED",
                        "Avatar này không có trong bộ sưu tập của bạn"));
        if (key.equals(user.getAvatarKey())) {
            return accounts.me(publicId); // đã dùng avatar này: không phát event lại
        }
        AvatarLibrary.Avatar avatar = AvatarLibrary.Avatar.fromKey(owned.getLibVersion(), key);
        users.setAvatar(publicId, key, owned.getLibVersion(), avatar.animal());
        outbox.publish(Topics.USER, EventTypes.AVATAR_CHANGED, publicId,
                new Events.AvatarChanged(publicId, avatar.code(), avatar.animal()));
        outbox.publish(Topics.USER, EventTypes.LEAD_ANIMAL_CHANGED, publicId,
                new Events.LeadAnimalChanged(publicId, avatar.animal()));
        return accounts.me(publicId);
    }

    /** "1:fox:0:glasses" → "fox:0:glasses". Phần phiên bản bị bỏ: nguồn sự thật là bản ghi trong bộ sưu tập. */
    private static String keyOf(String code) {
        int colon = code == null ? -1 : code.indexOf(':');
        if (colon <= 0 || colon == code.length() - 1) {
            throw ApiException.badRequest("AVATAR_NOT_OWNED", "Mã avatar không hợp lệ");
        }
        return code.substring(colon + 1);
    }

    @Transactional(readOnly = true)
    public List<Dtos.AvatarView> collection(String publicId) {
        return userAvatars.findByPublicIdOrderByCreatedAtAsc(publicId).stream()
                .map(v -> new Dtos.AvatarView(v.getLibVersion() + ":" + v.getAvatarKey(), v.getSource().name(),
                        v.getCreatedAt()))
                .toList();
    }
}
