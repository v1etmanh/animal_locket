import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:animal_locket/features/profile/domain/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileData {
  const ProfileData({
    required this.profile,
    required this.owned,
    required this.catalog,
    this.lastSpin,
  });
  final MeProfile profile;
  final List<Animal> owned;
  final List<Animal> catalog;
  final SpinResult? lastSpin;
  ProfileData copyWith({
    MeProfile? profile,
    List<Animal>? owned,
    SpinResult? lastSpin,
  }) => ProfileData(
    profile: profile ?? this.profile,
    owned: owned ?? this.owned,
    catalog: catalog,
    lastSpin: lastSpin ?? this.lastSpin,
  );
}

class ProfileController extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() => _load();
  Future<ProfileData> _load() async {
    final repository = ref.read(userRepositoryProvider);
    final profile = await repository.me();
    final owned = await repository.ownedAnimals();
    final catalog = await repository.animals();
    return ProfileData(profile: profile, owned: owned, catalog: catalog);
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_load);
  Future<SpinResult> spin() async {
    final result = await ref.read(userRepositoryProvider).spin();
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          owned: [...current.owned, result.animal],
          lastSpin: result,
        ),
      );
    }
    return result;
  }

  Future<void> setLeadAnimal(String code) async {
    final profile = await ref.read(userRepositoryProvider).setLeadAnimal(code);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(profile: profile));
  }

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
