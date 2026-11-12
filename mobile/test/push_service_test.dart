import 'dart:async';

import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/config/app_config.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/features/devices/data/push_preference.dart';
import 'package:animal_locket/features/devices/data/push_service.dart';
import 'package:animal_locket/features/devices/domain/devices_repository.dart';
import 'package:animal_locket/features/devices/presentation/push_controller.dart';
import 'package:animal_locket/features/devices/presentation/push_status_tile.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

class _Messaging extends Mock implements FirebaseMessaging {}

class _Settings extends Mock implements NotificationSettings {}

class _FirebaseApp extends Mock implements FirebaseApp {}

class _Push extends Mock implements PushService {}

class _Devices implements DevicesRepository {
  final registrations = <String>[];
  final removed = <String>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    if (fail) throw StateError('offline');
    await gate?.future;
    registrations.add('$platform:$token');
  }

  @override
  Future<void> unregister(String token) async => removed.add(token);
}

class _Auth extends AuthController {
  @override
  AuthState build() => const AuthState.unauthenticated();
  void update(AuthState value) => state = value;
}

const _config = AppConfig(
  apiBaseUrl: 'https://example.test',
  webSocketUrl: 'wss://example.test',
  keycloakIssuer: 'https://example.test/realm',
  keycloakClientId: 'test',
  oauthRedirectUrl: 'test:/oauth',
  enablePush: true,
  enableBilling: false,
  backendTests: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Messaging messaging;
  late _Settings settings;
  late _Devices devices;
  late PushService service;
  late StreamController<String> registered;

  setUp(() {
    messaging = _Messaging();
    settings = _Settings();
    devices = _Devices();
    registered = StreamController<String>.broadcast();
    when(() => settings.authorizationStatus)
        .thenReturn(AuthorizationStatus.authorized);
    when(() => messaging.requestPermission()).thenAnswer((_) async => settings);
    when(
      () => messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      ),
    ).thenAnswer((_) async {});
    when(() => messaging.onRegistered).thenAnswer((_) => registered.stream);
    when(() => messaging.register()).thenAnswer((_) async {
      registered.add('initial');
    });
    when(() => messaging.unregister()).thenAnswer((_) async {});
    service = PushService(messaging, devices);
  });
  tearDown(() async {
    service.dispose();
    await registered.close();
  });

  test(
    'persists initial token and refreshes; stops listening after logout',
    () async {
      await service.initialize();
      expect(devices.registrations, ['ANDROID:initial']);
      registered.add('renewed');
      await Future<void>.delayed(Duration.zero);
      expect(service.currentToken, 'renewed');
      await service.unregister();
      registered.add('after-logout');
      await Future<void>.delayed(Duration.zero);
      expect(devices.registrations, ['ANDROID:initial', 'ANDROID:renewed']);
      expect(devices.removed, ['renewed']);
      verify(() => messaging.unregister()).called(1);
    },
  );

  test('denied permission does not register a device', () async {
    when(() => settings.authorizationStatus)
        .thenReturn(AuthorizationStatus.denied);
    await expectLater(
      service.initialize(),
      throwsA(isA<PushPermissionDenied>()),
    );
    expect(devices.registrations, isEmpty);
    verifyNever(() => messaging.register());
  });

  test('failed device registration is visible and can be retried', () async {
    devices.fail = true;
    await expectLater(service.initialize(), throwsStateError);
    expect(service.currentToken, isNull);
    devices.fail = false;
    await service.initialize();
    expect(service.currentToken, 'initial');
  });

  test('logout drains an in-flight PUT before deleting registration', () async {
    await service.initialize();
    devices.gate = Completer<void>();
    registered.add('in-flight');
    await Future<void>.delayed(Duration.zero);
    final logout = service.unregister();
    devices.gate!.complete();
    await logout;
    expect(devices.removed, ['in-flight']);
    expect(service.currentToken, isNull);
  });

  test('bootstrap waits for a live authenticated profile', () async {
    final push = _Push();
    var firebaseStarts = 0;
    when(() => push.initialize()).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        authControllerProvider.overrideWith(_Auth.new),
        firebaseAppProvider.overrideWith((_) async {
          firebaseStarts++;
          return _FirebaseApp();
        }),
        pushServiceProvider.overrideWithValue(push),
        pushPreferenceStoreProvider.overrideWithValue(
          MemoryPushPreferenceStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(pushBootstrapProvider.future);
    expect(firebaseStarts, 0);
    final auth = container.read(authControllerProvider.notifier) as _Auth;
    auth.update(const AuthState.needsProfile());
    await container.read(pushBootstrapProvider.future);
    expect(firebaseStarts, 0);
    final profile = MeProfile.fromJson({'publicId': 'test'});
    container.read(backendModeProvider.notifier).useDemo();
    auth.update(AuthState.ready(profile));
    await container.read(pushBootstrapProvider.future);
    expect(firebaseStarts, 0);
    container.read(backendModeProvider.notifier).useLive();
    await container.read(pushBootstrapProvider.future);
    expect(firebaseStarts, 1);
    verify(() => push.initialize()).called(1);
  });

  test('routes only supported notification types', () {
    expect(
      pushDestination({'type': 'MESSAGE', 'conversationId': 'room/1'}),
      '/chat/room%2F1',
    );
    expect(pushDestination({'type': 'MESSAGE'}), '/chat');
    expect(pushDestination({'type': 'FRIEND_REQUEST'}), '/friends');
    expect(pushDestination({'type': 'NEW_POST', 'postId': 'p'}), '/feed');
    expect(pushDestination({'type': 'SUBSCRIPTION'}), '/profile');
    expect(
      pushDestination({'type': 'unknown', 'route': 'https://example.test'}),
      isNull,
    );
  });

  testWidgets('push status shows loading then successful registration', (
    tester,
  ) async {
    final registration = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          firebaseAppProvider.overrideWith((_) async => _FirebaseApp()),
          pushPreferenceStoreProvider.overrideWithValue(
            MemoryPushPreferenceStore(),
          ),
          pushBootstrapProvider.overrideWith((_) => registration.future),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: PushStatusTile()),
        ),
      ),
    );
    expect(find.text('Đang đăng ký nhận thông báo…'), findsOneWidget);
    registration.complete();
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị đã đăng ký nhận thông báo.'), findsOneWidget);
  });

  testWidgets('denied permission is visible and retry recovers', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          firebaseAppProvider.overrideWith((_) async => _FirebaseApp()),
          pushPreferenceStoreProvider.overrideWithValue(
            MemoryPushPreferenceStore(),
          ),
          pushBootstrapProvider.overrideWith((_) async {
            if (++attempts == 1) throw const PushPermissionDenied();
          }),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: PushStatusTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data),
      contains(
        'Quyền thông báo đã bị từ chối. Hãy bật lại trong cài đặt điện thoại.',
      ),
    );
    expect(find.text('Mở cài đặt'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Thiết bị đã đăng ký nhận thông báo.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('success shows switch on without a retry button', (tester) async {
    await tester.pumpWidget(
      _tile([pushBootstrapProvider.overrideWith((_) async {})]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị đã đăng ký nhận thông báo.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Mở cài đặt'), findsNothing);
  });

  testWidgets('registration failure shows retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _tile([
        pushBootstrapProvider.overrideWith((_) async {
          if (++attempts == 1) throw StateError('offline');
        }),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa đăng ký được thông báo. Vui lòng thử lại.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('switching off unregisters, persists and stays off', (
    tester,
  ) async {
    final push = _Push();
    when(() => push.unregister()).thenAnswer((_) async {});
    final store = MemoryPushPreferenceStore();
    var bootstraps = 0;
    await tester.pumpWidget(
      _tile(
        [pushServiceProvider.overrideWithValue(push)],
        store: store,
        bootstrap: () => bootstraps++,
      ),
    );
    await tester.pumpAndSettle();
    expect(bootstraps, 1);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    verify(() => push.unregister()).called(1);
    expect(await store.read(), isFalse);
    expect(bootstraps, 1);
    expect(find.text('Thông báo đang tắt trên thiết bị này.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(await store.read(), isTrue);
    expect(bootstraps, 2);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('denied permission opens app settings', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _tile([
        pushBootstrapProvider.overrideWith(
          (_) async => throw const PushPermissionDenied(),
        ),
        openAppSettingsProvider.overrideWithValue(() async => opened++),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở cài đặt'));
    expect(opened, 1);
  });
}

/// Tile với bootstrap thật gắn sẵn preference; [bootstrap] đếm số lần đăng ký.
Widget _tile(
  List overrides, {
  PushPreferenceStore? store,
  void Function()? bootstrap,
}) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(_config),
    firebaseAppProvider.overrideWith((_) async => _FirebaseApp()),
    pushPreferenceStoreProvider.overrideWithValue(
      store ?? MemoryPushPreferenceStore(),
    ),
    if (bootstrap != null)
      pushBootstrapProvider.overrideWith((ref) async {
        if (!await ref.watch(pushPreferenceProvider.future)) return;
        bootstrap();
      }),
    ...overrides.cast(),
  ],
  child: const MaterialApp(
    locale: Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: PushStatusTile()),
  ),
);
