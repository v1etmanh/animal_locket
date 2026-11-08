import 'package:animal_locket/core/avatar/my_avatar_store.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/network/api_client.dart';
import 'package:animal_locket/features/profile/domain/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiveUserRepository implements UserRepository {
  const LiveUserRepository(this._api, [this._store = const MyAvatarStore()]);
  final ApiClient _api;
  final MyAvatarStore _store;

  @override
  Future<MeProfile> me() async => _remember(
    MeProfile.fromJson(
      (await _api.get<Map<String, dynamic>>('/users/me')).data!,
    ),
  );

  /// Lưu avatar của tôi vào máy (bản đệm; server vẫn là nguồn sự thật).
  MeProfile _remember(MeProfile p) {
    _store.save(publicId: p.publicId, avatar: p.avatar);
    return p;
  }

  @override
  Future<MeProfile> register({required String birthDate, String? alias}) async {
    final normalizedAlias = alias?.trim();
    final response = await _api.post<Map<String, dynamic>>(
      '/users/register',
      data: {
        'birthDate': birthDate,
        'alias': ?(normalizedAlias?.isEmpty == false ? normalizedAlias : null),
      },
    );
    return _remember(MeProfile.fromJson(response.data!));
  }

  @override
  Future<MeProfile> update({String? alias, bool? discoverable}) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'alias': ?alias, 'discoverable': ?discoverable},
    );
    return MeProfile.fromJson(response.data!);
  }

  @override
  Future<void> deleteAccount() async {
    await _api.delete<void>('/users/me');
    await _store.clear();
  }

  @override
  Future<PublicProfile> publicProfile(String publicId) async =>
      PublicProfile.fromJson(
        (await _api.get<Map<String, dynamic>>('/users/$publicId')).data!,
      );

  @override
  Future<List<OwnedAvatar>> myAvatars() async {
    final data =
        (await _api.get<List<dynamic>>('/users/me/avatars')).data ?? const [];
    final list = data
        .cast<Map<String, dynamic>>()
        .map(OwnedAvatar.fromJson)
        .toList();
    return list;
  }
}

class DemoUserRepository implements UserRepository {
  MeProfile _profile = MeProfile(
    publicId: 'demodemodemodemodemo',
    alias: 'Nắng Lấp Lánh',
    leadAnimal: 'fox',
    avatar: '1:fox:0:glasses',
    ageGroup: AgeGroup.adult,
    discoverable: true,
    plan: AccountPlan.free,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  @override
  Future<MeProfile> me() async => _profile;

  @override
  Future<MeProfile> register({required String birthDate, String? alias}) async {
    if (alias?.trim().isNotEmpty == true) {
      _profile = _copy(alias: alias!.trim());
    }
    return _profile;
  }

  @override
  Future<MeProfile> update({String? alias, bool? discoverable}) async {
    _profile = _copy(alias: alias, discoverable: discoverable);
    return _profile;
  }

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<PublicProfile> publicProfile(String publicId) async => PublicProfile(
    publicId: publicId,
    alias: 'Mây Bồng Bềnh',
    leadAnimal: 'panda',
    avatar: '1:panda:6:bow',
  );

  @override
  Future<List<OwnedAvatar>> myAvatars() async => [
    OwnedAvatar(
      avatar: _profile.avatar!,
      source: 'REGISTER',
      acquiredAt: _profile.createdAt,
    ),
  ];

  MeProfile _copy({String? alias, bool? discoverable}) => MeProfile(
    publicId: _profile.publicId,
    alias: alias ?? _profile.alias,
    leadAnimal: _profile.leadAnimal,
    avatar: _profile.avatar,
    ageGroup: _profile.ageGroup,
    discoverable: discoverable ?? _profile.discoverable,
    plan: _profile.plan,
    createdAt: _profile.createdAt,
  );
}

final liveUserRepositoryProvider = Provider<UserRepository>((ref) {
  return LiveUserRepository(ref.watch(apiClientProvider));
});

final demoUserRepositoryProvider = Provider<UserRepository>((ref) {
  return DemoUserRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return ref.watch(backendModeProvider) == BackendMode.demo
      ? ref.watch(demoUserRepositoryProvider)
      : ref.watch(liveUserRepositoryProvider);
});
