import 'package:animal_locket/core/config/app_config.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/features/devices/data/push_service.dart';
import 'package:animal_locket/features/devices/presentation/push_controller.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushStatusTile extends ConsumerWidget {
  const PushStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context)!;
    final enabled =
        ref.watch(appConfigProvider).enablePush &&
        ref.watch(backendModeProvider) == BackendMode.live;
    final state = ref.watch(pushBootstrapProvider);
    return ListTile(
      title: Text(text.pushTitle),
      subtitle: Text(
        !enabled
            ? text.pushDisabled
            : state.when(
                loading: () => text.pushLoading,
                error: (error, _) => error is PushPermissionDenied
                    ? text.pushDenied
                    : text.pushError,
                data: (_) => text.pushRegistered,
              ),
      ),
      trailing: !enabled
          ? null
          : state.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            )
          : TextButton(
              onPressed: () {
                if (ref.read(firebaseAppProvider).hasError) {
                  ref.invalidate(firebaseAppProvider);
                }
                ref.invalidate(pushBootstrapProvider);
              },
              child: Text(text.pushRetry),
            ),
    );
  }
}
