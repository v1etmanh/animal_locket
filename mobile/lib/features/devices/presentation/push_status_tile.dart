import 'package:animal_locket/core/config/app_config.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
import 'package:animal_locket/features/devices/data/push_preference.dart';
import 'package:animal_locket/features/devices/data/push_service.dart';
import 'package:animal_locket/features/devices/presentation/push_controller.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Mở trang cài đặt của app (thay được trong test).
final openAppSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await openAppSettings();
  },
);

/// Công tắc thông báo:
/// - đã đăng ký → bật; tắt → gỡ thiết bị khỏi FCM và backend;
/// - bật → bootstrap xin quyền (nếu cần) rồi đăng ký;
/// - lỗi đăng ký → mới hiện "Thử lại";
/// - quyền bị chặn → công tắc tắt kèm nút "Mở cài đặt".
class PushStatusTile extends ConsumerStatefulWidget {
  const PushStatusTile({super.key});

  @override
  ConsumerState<PushStatusTile> createState() => _PushStatusTileState();
}

class _PushStatusTileState extends ConsumerState<PushStatusTile> {
  bool _turningOff = false;

  void _retry() {
    if (ref.read(firebaseAppProvider).hasError) {
      ref.invalidate(firebaseAppProvider);
    }
    ref.invalidate(pushBootstrapProvider);
  }

  Future<void> _toggle(bool value, bool wanted) async {
    final preference = ref.read(pushPreferenceProvider.notifier);
    if (value) {
      // Đang muốn bật mà công tắc tắt (lỗi/bị chặn) thì gạt lên = thử lại.
      if (wanted) {
        _retry();
      } else {
        await preference.setEnabled(true);
      }
      return;
    }
    setState(() => _turningOff = true);
    try {
      await preference.setEnabled(false);
    } finally {
      if (mounted) setState(() => _turningOff = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final available =
        ref.watch(appConfigProvider).enablePush &&
        ref.watch(backendModeProvider) == BackendMode.live;
    if (!available) {
      return ListTile(
        title: Text(text.pushTitle),
        subtitle: Text(text.pushDisabled),
      );
    }
    final preference = ref.watch(pushPreferenceProvider);
    final state = ref.watch(pushBootstrapProvider);
    final wanted = preference.value ?? true;
    final busy = _turningOff || preference.isLoading || state.isLoading;
    final error = state.hasError ? state.error : null;
    final denied = wanted && error is PushPermissionDenied;
    final failed = wanted && error != null && !denied;
    final registered = wanted && !busy && error == null;

    final String status;
    if (_turningOff) {
      status = text.pushTurningOff;
    } else if (busy) {
      status = text.pushLoading;
    } else if (!wanted) {
      status = text.pushOff;
    } else if (denied) {
      status = text.pushDenied;
    } else if (failed) {
      status = text.pushError;
    } else {
      status = text.pushRegistered;
    }

    Widget? action;
    if (!busy && denied) {
      action = TextButton(
        onPressed: () => ref.read(openAppSettingsProvider)(),
        child: Text(text.pushOpenSettings),
      );
    } else if (!busy && failed) {
      action = TextButton(onPressed: _retry, child: Text(text.pushRetry));
    }

    return ListTile(
      title: Text(text.pushTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status),
          if (action != null)
            Align(alignment: Alignment.centerLeft, child: action),
        ],
      ),
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            )
          : Switch(
              value: registered,
              onChanged: (value) => _toggle(value, wanted),
            ),
    );
  }
}
