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
  const PublicProfile({required this.publicId, this.alias, this.leadAnimal});

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    publicId: json['publicId'] as String? ?? '',
    alias: json['alias'] as String?,
    leadAnimal: json['leadAnimal'] as String?,
  );

  final String publicId;
  final String? alias;
  final String? leadAnimal;

  String get displayAlias =>
      alias?.trim().isNotEmpty == true ? alias! : 'Người bạn ẩn danh';
}

class MeProfile extends PublicProfile {
  const MeProfile({
    required super.publicId,
    super.alias,
    super.leadAnimal,
    required this.ageGroup,
    required this.discoverable,
    required this.plan,
    required this.createdAt,
  });

  factory MeProfile.fromJson(Map<String, dynamic> json) => MeProfile(
    publicId: json['publicId'] as String? ?? '',
    alias: json['alias'] as String?,
    leadAnimal: json['leadAnimal'] as String?,
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
