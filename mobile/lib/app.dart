import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/l10n/locale_controller.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/core/network/api_client.dart';
import 'package:animal_locket/core/router/app_router.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/app_theme.dart';
import 'package:animal_locket/core/theme/theme_controller.dart';
import 'package:animal_locket/features/devices/presentation/push_controller.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _pushMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AnimalLocketApp extends ConsumerWidget {
  const AnimalLocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushBootstrapProvider);
    ref.listen(openedPushProvider, (_, next) {
      final message = next.value;
      if (message == null) return;
      final destination = pushDestination(message.data);
      if (destination != null) ref.read(appRouterProvider).go(destination);
    });
    ref.listen(foregroundPushProvider, (_, next) {
      if (next.value == null) return;
      final messenger = _pushMessengerKey.currentState;
      if (messenger == null) return;
      final text = AppLocalizations.of(messenger.context)!;
      // Use generic text even if a provider accidentally includes private content.
      messenger.showSnackBar(SnackBar(content: Text(text.pushIncoming)));
    });
    ref.watch(avatarRemoteBootstrapProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: _pushMessengerKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      theme: AppTheme.forPalette(
        AlbumPalette.of(ref.watch(albumThemeProvider)),
      ),
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

/// Cho phép tải thư viện avatar phiên bản mới (app chỉ đóng gói sẵn v1).
final avatarRemoteBootstrapProvider = Provider<void>((ref) {
  if (ref.watch(backendModeProvider) == BackendMode.demo) return;
  final api = ref.watch(apiClientProvider);
  AvatarLibraries.instance.remote = (version) async =>
      (await api.get<Map<String, dynamic>>('/animals/avatar-lib/$version'))
          .data!;
});
