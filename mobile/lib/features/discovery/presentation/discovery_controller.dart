import 'dart:async';

import 'package:animal_locket/features/discovery/data/discovery_repository_impl.dart';
import 'package:animal_locket/features/discovery/domain/discovery_repository.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class DiscoveryState {
  const DiscoveryState({
    required this.enabled,
    this.cards = const [],
    this.swipesLeftToday = 0,
    this.degraded = false,
    this.busy = false,
    this.lastResult,
  });
  final bool enabled;
  final List<DiscoveryCard> cards;
  final int swipesLeftToday;
  final bool degraded;
  final bool busy;
  final String? lastResult;
  DiscoveryState copyWith({
    bool? enabled,
    List<DiscoveryCard>? cards,
    int? swipesLeftToday,
    bool? degraded,
    bool? busy,
    String? lastResult,
  }) => DiscoveryState(
    enabled: enabled ?? this.enabled,
    cards: cards ?? this.cards,
    swipesLeftToday: swipesLeftToday ?? this.swipesLeftToday,
    degraded: degraded ?? this.degraded,
    busy: busy ?? this.busy,
    lastResult: lastResult,
  );
}

class DiscoveryController extends AsyncNotifier<DiscoveryState> {
  Timer? _heartbeatTimer;
  bool _active = false;
  @override
  Future<DiscoveryState> build() async {
    ref.onDispose(() => _heartbeatTimer?.cancel());
    final profile = await ref.read(userRepositoryProvider).me();
    if (!profile.discoverable) return const DiscoveryState(enabled: false);
    return _loadDeck(enabled: true);
  }

  Future<DiscoveryState> _loadDeck({required bool enabled}) async {
    final deck = await ref.read(discoveryRepositoryProvider).cards();
    return DiscoveryState(
      enabled: enabled,
      cards: deck.cards,
      swipesLeftToday: deck.swipesLeftToday,
      degraded: deck.degraded,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(
    () => _loadDeck(enabled: state.value?.enabled ?? true),
  );
  Future<void> enable() async {
    state = const AsyncLoading();
    try {
      await ref.read(userRepositoryProvider).update(discoverable: true);
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition();
        await ref
            .read(discoveryRepositoryProvider)
            .updateLocation(lat: position.latitude, lon: position.longitude);
      }
      state = AsyncData(await _loadDeck(enabled: true));
      setActive(_active);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<String?> swipe(bool right) async {
    final current = state.value;
    if (current == null || current.cards.isEmpty || current.busy) return null;
    final card = current.cards.first;
    state = AsyncData(current.copyWith(busy: true));
    try {
      final result = await ref
          .read(discoveryRepositoryProvider)
          .swipe(card.publicId, right: right);
      final remaining = current.cards.skip(1).toList();
      state = AsyncData(
        current.copyWith(
          cards: remaining,
          swipesLeftToday: result.swipesLeftToday,
          busy: false,
          lastResult: result.result,
        ),
      );
      if (remaining.length <= 3) unawaited(_prefetch());
      return result.result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _prefetch() async {
    final current = state.value;
    if (current == null) return;
    final deck = await ref.read(discoveryRepositoryProvider).cards();
    final seen = current.cards.map((item) => item.publicId).toSet();
    state = AsyncData(
      current.copyWith(
        cards: [
          ...current.cards,
          ...deck.cards.where((item) => seen.add(item.publicId)),
        ],
        swipesLeftToday: deck.swipesLeftToday,
        degraded: current.degraded || deck.degraded,
      ),
    );
  }

  Future<void> boost() => ref.read(discoveryRepositoryProvider).boost();
  void setActive(bool active) {
    _active = active;
    _heartbeatTimer?.cancel();
    if (!active || state.value?.enabled != true) return;
    unawaited(ref.read(discoveryRepositoryProvider).heartbeat());
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(ref.read(discoveryRepositoryProvider).heartbeat()),
    );
  }
}

final discoveryControllerProvider =
    AsyncNotifierProvider<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );
