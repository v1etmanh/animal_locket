import 'package:animal_locket/core/models/common_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Avatar hiện tại của chính người dùng, cập nhật ngay khi đổi avatar hoặc quay được avatar mới.
///
/// Danh sách bài đăng do server trả về, mà post-service cache hồ sơ tác giả vài phút (docs/19 §7),
/// và feed đã tải hoặc lưu đệm vẫn giữ avatar cũ. Nên bài của chính mình phải lấy avatar từ đây.
class CurrentAvatar {
  const CurrentAvatar({required this.publicId, this.avatar, this.leadAnimal});

  final String publicId;
  final String? avatar;
  final String? leadAnimal;
}

class CurrentAvatarController extends Notifier<CurrentAvatar?> {
  @override
  CurrentAvatar? build() => null;

  void set(PublicProfile profile) => state = CurrentAvatar(
    publicId: profile.publicId,
    avatar: profile.avatar,
    leadAnimal: profile.leadAnimal,
  );
}

final currentAvatarProvider =
    NotifierProvider<CurrentAvatarController, CurrentAvatar?>(
      CurrentAvatarController.new,
    );
