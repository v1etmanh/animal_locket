import 'package:animal_locket/core/models/common_models.dart';

class SpinResult {
  const SpinResult({required this.animal, required this.nextSpinAt});
  final Animal animal;
  final DateTime? nextSpinAt;
}

abstract interface class UserRepository {
  Future<MeProfile> me();
  Future<MeProfile> register({required String birthDate, String? alias});
  Future<MeProfile> update({String? alias, bool? discoverable});
  Future<void> deleteAccount();
  Future<PublicProfile> publicProfile(String publicId);
  Future<List<Animal>> animals();
  Future<List<Animal>> ownedAnimals();
  Future<SpinResult> spin();
  Future<MeProfile> setLeadAnimal(String animalCode);
}
