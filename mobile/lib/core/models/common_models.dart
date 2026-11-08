enum AgeGroup { minor, adult }

enum AccountPlan { free, pro }

enum AnimalRarity { common, rare, epic, unknown }

class Animal {
  const Animal({
    required this.code,
    required this.name,
    required this.rarity,
    this.packCode,
  });

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
    code: json['code'] as String? ?? 'unknown',
    name: json['name'] as String? ?? 'Con vật',
    rarity: switch (json['rarity']) {
      'COMMON' => AnimalRarity.common,
      'RARE' => AnimalRarity.rare,
      'EPIC' => AnimalRarity.epic,
      _ => AnimalRarity.unknown,
    },
    packCode: json['packCode'] as String?,
  );

  final String code;
  final String name;
  final AnimalRarity rarity;
  final String? packCode;

  String get rarityLabel => switch (rarity) {
    AnimalRarity.common => 'Phổ thông',
    AnimalRarity.rare => 'Hiếm',
    AnimalRarity.epic => 'Sử thi',
    AnimalRarity.unknown => 'Chưa rõ',
  };
}

class PublicProfile {
  const PublicProfile({
    required this.publicId,
    this.alias,
    this.leadAnimal,
    this.avatar,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    publicId: json['publicId'] as String? ?? '',
    alias: json['alias'] as String?,
    leadAnimal: json['leadAnimal'] as String?,
    avatar: json['avatar'] as String?,
  );

  final String publicId;
  final String? alias;
  final String? leadAnimal;

  /// Mã avatar duy nhất "v:animal:palette:accessory"; vẽ bằng AnimalAvatar(avatar: ...).
  final String? avatar;

  String get displayAlias =>
      alias?.trim().isNotEmpty == true ? alias! : 'Người bạn ẩn danh';
}

class MeProfile extends PublicProfile {
  const MeProfile({
    required super.publicId,
    super.alias,
    super.leadAnimal,
    super.avatar,
    required this.ageGroup,
    required this.discoverable,
    required this.plan,
    required this.createdAt,
  });

  factory MeProfile.fromJson(Map<String, dynamic> json) => MeProfile(
    publicId: json['publicId'] as String? ?? '',
    alias: json['alias'] as String?,
    leadAnimal: json['leadAnimal'] as String?,
    avatar: json['avatar'] as String?,
    ageGroup: json['ageGroup'] == 'MINOR' ? AgeGroup.minor : AgeGroup.adult,
    discoverable: json['discoverable'] as bool? ?? false,
    plan: json['plan'] == 'PRO' ? AccountPlan.pro : AccountPlan.free,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final AgeGroup ageGroup;
  final bool discoverable;
  final AccountPlan plan;
  final DateTime createdAt;
}

/// Một avatar trong bộ sưu tập (GET /users/me/avatars).
class OwnedAvatar {
  const OwnedAvatar({
    required this.avatar,
    required this.source,
    this.acquiredAt,
  });

  factory OwnedAvatar.fromJson(Map<String, dynamic> json) => OwnedAvatar(
    avatar: json['avatar'] as String? ?? '',
    source: json['source'] as String? ?? 'REGISTER',
    acquiredAt: DateTime.tryParse(json['acquiredAt'] as String? ?? '')?.toUtc(),
  );

  final String avatar;
  final String source;
  final DateTime? acquiredAt;
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    this.nextBefore,
    this.nextAfter,
    this.degraded = false,
  });

  final List<T> items;
  final String? nextBefore;
  final int? nextAfter;
  final bool degraded;
}
