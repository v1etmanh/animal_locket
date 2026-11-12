import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/config/app_config.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/features/devices/data/push_preference.dart';
import 'package:animal_locket/features/devices/data/push_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

bool _canReceive(Ref ref) =>
    ref.watch(appConfigProvider).enablePush &&
    ref.watch(backendModeProvider) == BackendMode.live &&
    ref.watch(authControllerProvider.select((auth) => auth.status)) ==
        AuthStatus.ready;

final pushBootstrapProvider = FutureProvider<void>(
  (ref) async {
    final status = ref.watch(
      authControllerProvider.select((auth) => auth.status),
    );
    if (!ref.watch(appConfigProvider).enablePush ||
        ref.watch(backendModeProvider) == BackendMode.demo ||
        status != AuthStatus.ready) {
      return;
    }
    // Người dùng đã tắt công tắc: không xin quyền, không đăng ký lại khi app resume.
    if (!await ref.watch(pushPreferenceProvider.future) || !ref.mounted) {
      return;
    }
    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(firebaseAppProvider).hasError) {
          ref.invalidate(firebaseAppProvider);
        }
        ref.invalidateSelf();
      },
    );
    ref.onDispose(lifecycle.dispose);
    try {
      await ref.watch(firebaseAppProvider.future);
      if (!ref.mounted) return;
      await ref.watch(pushServiceProvider)?.initialize();
    } catch (error, stack) {
      debugPrint('Push registration failed: $error\n$stack');
      rethrow;
    }
  },
  // Permission/configuration errors need to remain visible until explicit retry.
  retry: (_, _) => null,
);

final foregroundPushProvider = StreamProvider<RemoteMessage>((ref) async* {
  if (!_canReceive(ref)) return;
  // Keep listeners alive during registration retries/resume so taps are not lost.
  await ref.watch(firebaseAppProvider.future);
  if (!ref.mounted) return;
  yield* FirebaseMessaging.onMessage;
});

final openedPushProvider = StreamProvider<RemoteMessage>((ref) async* {
  if (!_canReceive(ref)) return;
  await ref.watch(firebaseAppProvider.future);
  if (!ref.mounted) return;
  final service = ref.watch(pushServiceProvider);
  if (service == null) return;
  yield* service.openedMessages();
});

String? pushDestination(Map<String, dynamic> data) => switch (data['type']) {
  'MESSAGE' =>
    data['conversationId'] is String &&
            (data['conversationId'] as String).isNotEmpty
        ? '/chat/${Uri.encodeComponent(data['conversationId'] as String)}'
        : '/chat',
  'FRIEND_REQUEST' || 'FRIEND_ACCEPTED' => '/friends',
  // MVP has no standalone post route: show feed rather than inventing a screen/API.
  'NEW_POST' || 'POST_LIKED' || 'POST_COMMENTED' => '/feed',
  'PHOTO_REJECTED' => '/camera',
  'SUBSCRIPTION' => '/profile',
  _ => null,
};
