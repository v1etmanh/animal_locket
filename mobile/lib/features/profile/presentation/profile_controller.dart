import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileData {
  const ProfileData({required this.profile, required this.avatars});
  final MeProfile profile;

  /// Bộ sưu tập avatar; mỗi avatar chỉ thuộc về mình, không ai khác có.
  final List<OwnedAvatar> avatars;

  ProfileData copyWith({MeProfile? profile}) =>
      ProfileData(profile: profile ?? this.profile, avatars: avatars);
}

class ProfileController extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() => _load();
  Future<ProfileData> _load() async {
    final repository = ref.read(userRepositoryProvider);
    final profile = await repository.me();
    final avatars = await repository.myAvatars();
    return ProfileData(profile: profile, avatars: avatars);
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_load);

  Future<void> updateAlias(String alias) async {
    final profile = await ref
        .read(userRepositoryProvider)
        .update(alias: alias.trim());
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(profile: profile));
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileData>(
      ProfileController.new,
    );
