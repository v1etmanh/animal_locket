class DiscoveryCard {
  const DiscoveryCard({
    required this.publicId,
    required this.alias,
    this.leadAnimal,
    this.distanceBand,
    required this.online,
    required this.boosted,
  });
  factory DiscoveryCard.fromJson(Map<String, dynamic> json) => DiscoveryCard(
    publicId: json['publicId'] as String? ?? '',
    alias: json['alias'] as String? ?? 'Người bạn ẩn danh',
    leadAnimal: json['leadAnimal'] as String?,
    distanceBand: json['distanceBand'] as String?,
    online: json['online'] as bool? ?? false,
    boosted: json['boosted'] as bool? ?? false,
  );
  final String publicId;
  final String alias;
  final String? leadAnimal;
  final String? distanceBand;
  final bool online;
  final bool boosted;
  String? get distanceLabel => switch (distanceBand) {
    'UNDER_1KM' => 'dưới 1 km',
    '1_TO_3KM' => '1–3 km',
    'UNDER_3KM' => 'dưới 3 km',
    '3_TO_10KM' => '3–10 km',
    'OVER_10KM' => 'trên 10 km',
    _ => null,
  };
}

class DiscoveryDeck {
  const DiscoveryDeck({
    required this.cards,
    required this.degraded,
    required this.swipesLeftToday,
  });
  final List<DiscoveryCard> cards;
  final bool degraded;
  final int swipesLeftToday;
}

class SwipeResult {
  const SwipeResult({required this.result, required this.swipesLeftToday});
  final String result;
  final int swipesLeftToday;
}

abstract interface class DiscoveryRepository {
  Future<void> updateLocation({required double lat, required double lon});
  Future<void> deleteLocation();
  Future<void> heartbeat();
  Future<DiscoveryDeck> cards({int limit = 20});
  Future<SwipeResult> swipe(String publicId, {required bool right});
  Future<void> boost();
}
