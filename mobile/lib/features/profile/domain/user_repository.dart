import 'package:animal_locket/core/models/common_models.dart';

abstract interface class UserRepository {
  Future<MeProfile> me();
  Future<MeProfile> register({required String birthDate, String? alias});
  Future<MeProfile> update({String? alias, bool? discoverable});
  Future<void> deleteAccount();
  Future<PublicProfile> publicProfile(String publicId);

  /// Bộ sưu tập avatar (mỗi avatar chỉ thuộc về một người). Quay thêm sẽ gắn với nạp tiền.
  Future<List<OwnedAvatar>> myAvatars();
}
