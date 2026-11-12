import 'dart:async';

import 'package:animal_locket/core/config/app_config.dart';
import 'package:animal_locket/features/devices/data/devices_repository_impl.dart';
import 'package:animal_locket/features/devices/domain/devices_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushService {
  PushService(this._messaging, this._devices);
  final FirebaseMessaging _messaging;
  final DevicesRepository _devices;
  String? currentToken;
  StreamSubscription<String>? _registrationEvents;
  int _generation = 0;
  Future<void> _pendingRegistration = Future<void>.value();
  Future<void>? _nativeRegistration;
  Future<void> initialize() async {
    final generation = ++_generation;
    await _registrationEvents?.cancel();
    final permission = await _messaging.requestPermission();
    if (generation != _generation) return;
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      throw const PushPermissionDenied();
    }
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (generation != _generation) return;
    // v17 emits both the initial token and later refreshes through onRegistered.
    // Subscribe before register() so the initial event cannot be missed.
    final firstRegistration = Completer<void>();
    _registrationEvents = _messaging.onRegistered.listen(
      (token) async {
        if (generation != _generation) return;
        try {
          await _register(token, generation);
          if (!firstRegistration.isCompleted) firstRegistration.complete();
        } catch (error, stack) {
          if (!firstRegistration.isCompleted) {
            firstRegistration.completeError(error, stack);
          }
          // Later failures are retried by reinitializing when the app resumes.
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!firstRegistration.isCompleted) {
          firstRegistration.completeError(error, stack);
        }
      },
    );
    // Consume errors immediately, including a timeout if register() itself fails.
    final registration = firstRegistration.future.timeout(
      const Duration(seconds: 30),
    );
    unawaited(registration.catchError((Object _) {}));
    final nativeRegistration = _messaging.register().timeout(
      const Duration(seconds: 30),
    );
    _nativeRegistration = nativeRegistration;
    await nativeRegistration;
    await registration;
  }

  Future<void> _register(String token, int generation) {
    final operation = _pendingRegistration.then((_) async {
      if (generation != _generation) return;
      await _devices.register(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'IOS'
            : 'ANDROID',
      );
      currentToken = token;
    });
    _pendingRegistration = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> unregister() async {
    ++_generation;
    await _registrationEvents?.cancel();
    _registrationEvents = null;
    try {
      await _nativeRegistration;
    } catch (_) {
      // Even a failed native registration still needs local FCM cleanup.
    }
    // Drain PUT requests before DELETE so logout cannot leave a late registration.
    await _pendingRegistration;
    final token = currentToken;
    try {
      if (token != null) await _devices.unregister(token);
    } finally {
      currentToken = null;
      await _messaging.unregister();
    }
  }

  Stream<RemoteMessage> openedMessages() async* {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) yield initial;
    yield* FirebaseMessaging.onMessageOpenedApp;
  }

  void dispose() {
    ++_generation;
    unawaited(_registrationEvents?.cancel());
  }
}

class PushPermissionDenied implements Exception {
  const PushPermissionDenied();
}

// Initialize only after authentication/profile bootstrap (see push_controller).
final firebaseAppProvider = FutureProvider<FirebaseApp>(
  (ref) async {
    return Firebase.initializeApp(options: firebaseOptionsFromEnvironment());
  },
  // Missing/mismatched build configuration should stay visible until retry.
  retry: (_, _) => null,
);

FirebaseOptions firebaseOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  final appId = defaultTargetPlatform == TargetPlatform.iOS
      ? const String.fromEnvironment('FIREBASE_IOS_APP_ID')
      : const String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  if ([apiKey, projectId, senderId, appId].any((value) => value.isEmpty)) {
    throw StateError('Missing Firebase dart-defines');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: const String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.animallocket.app',
    ),
  );
}

final pushServiceProvider = Provider<PushService?>((ref) {
  if (!ref.watch(appConfigProvider).enablePush) return null;
  if (!ref.watch(firebaseAppProvider).hasValue) return null;
  final service = PushService(
    FirebaseMessaging.instance,
    ref.watch(devicesRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
