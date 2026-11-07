import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/network/api_client.dart';
import 'package:animal_locket/features/profile/domain/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiveUserRepository implements UserRepository {
  const LiveUserRepository(this._api);
  final ApiClient _api;

  @override
  Future<MeProfile> me() async => MeProfile.fromJson(
    (await _api.get<Map<String, dynamic>>('/users/me')).data!,
  );

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
    return MeProfile.fromJson(response.data!);
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
  Future<void> deleteAccount() async => _api.delete<void>('/users/me');

  @override
  Future<PublicProfile> publicProfile(String publicId) async =>
      PublicProfile.fromJson(
        (await _api.get<Map<String, dynamic>>('/users/$publicId')).data!,
      );

  @override
  Future<List<Animal>> animals() async {
    final data = (await _api.get<List<dynamic>>('/animals')).data ?? const [];
    return data.cast<Map<String, dynamic>>().map(Animal.fromJson).toList();
  }

  @override
  Future<List<Animal>> ownedAnimals() async {
    final data =
        (await _api.get<List<dynamic>>('/users/me/animals')).data ?? const [];
    return data.cast<Map<String, dynamic>>().map(Animal.fromJson).toList();
  }

  @override
  Future<SpinResult> spin() async {
    final data = (await _api.post<Map<String, dynamic>>('/users/me/spin'))
        .data!;
    return SpinResult(
      animal: Animal.fromJson(data['animal'] as Map<String, dynamic>),
      nextSpinAt: DateTime.tryParse(data['nextSpinAt'] as String? ?? '')
          ?.toUtc(),
    );
  }

  @override
  Future<MeProfile> setLeadAnimal(String animalCode) async =>
      MeProfile.fromJson(
        (await _api.put<Map<String, dynamic>>(
          '/users/me/lead-animal',
          data: {'animalCode': animalCode},
        )).data!,
      );
}

class DemoUserRepository implements UserRepository {
  MeProfile _profile = MeProfile(
    publicId: 'demodemodemodemodemo',
    alias: 'Nắng Lấp Lánh',
    leadAnimal: 'fox',
    ageGroup: AgeGroup.adult,
    discoverable: true,
    plan: AccountPlan.free,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  static const _animals = [
    Animal(code: 'fox', name: 'Cáo Mặt Trời', rarity: AnimalRarity.common),
    Animal(code: 'panda', name: 'Gấu trúc', rarity: AnimalRarity.rare),
    Animal(code: 'tiger', name: 'Hổ Mơ Màng', rarity: AnimalRarity.epic),
    Animal(code: 'rabbit', name: 'Thỏ Tháng Tư', rarity: AnimalRarity.common),
    Animal(code: 'otter', name: 'Rái cá', rarity: AnimalRarity.rare),
  ];

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
  );

  @override
  Future<List<Animal>> animals() async => _animals;

  @override
  Future<List<Animal>> ownedAnimals() async => _animals;

  @override
  Future<SpinResult> spin() async => SpinResult(
    animal: _animals.last,
    nextSpinAt: DateTime.now().toUtc().add(const Duration(hours: 24)),
  );

  @override
  Future<MeProfile> setLeadAnimal(String animalCode) async {
    _profile = _copy(leadAnimal: animalCode);
    return _profile;
  }

  MeProfile _copy({String? alias, String? leadAnimal, bool? discoverable}) =>
      MeProfile(
        publicId: _profile.publicId,
        alias: alias ?? _profile.alias,
        leadAnimal: leadAnimal ?? _profile.leadAnimal,
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
