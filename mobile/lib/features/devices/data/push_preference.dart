import 'package:animal_locket/features/devices/data/push_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lựa chọn bật/tắt thông báo trên máy này (mặc định bật).
abstract interface class PushPreferenceStore {
  Future<bool?> read();
  Future<void> write(bool enabled);
}

class SecurePushPreferenceStore implements PushPreferenceStore {
  const SecurePushPreferenceStore(this._storage);
  static const _key = 'push_enabled';
  final FlutterSecureStorage _storage;

  @override
  Future<bool?> read() async => switch (await _storage.read(key: _key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  @override
  Future<void> write(bool enabled) =>
      _storage.write(key: _key, value: '$enabled');
}

class MemoryPushPreferenceStore implements PushPreferenceStore {
  MemoryPushPreferenceStore([this._value]);
  bool? _value;

  @override
  Future<bool?> read() async => _value;

  @override
  Future<void> write(bool enabled) async => _value = enabled;
}

final pushPreferenceStoreProvider = Provider<PushPreferenceStore>(
  (ref) => const SecurePushPreferenceStore(FlutterSecureStorage()),
);

class PushPreference extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(pushPreferenceStoreProvider).read() ?? true;
    } catch (_) {
      // Không đọc được kho: giữ mặc định bật như trước khi có công tắc.
      return true;
    }
  }

  /// Bật: bootstrap tự chạy lại (xin quyền nếu cần rồi đăng ký FCM).
  /// Tắt: gỡ token khỏi FCM và xoá thiết bị khỏi backend.
  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    try {
      await ref.read(pushPreferenceStoreProvider).write(enabled);
    } catch (_) {
      // Không lưu được thì vẫn áp dụng cho phiên này.
    }
    if (enabled) return;
    try {
      await ref.read(pushServiceProvider)?.unregister();
    } catch (error) {
      // unregister() vẫn gỡ token FCM cục bộ trong finally nên máy không nhận push nữa.
      debugPrint('Tắt thông báo: gỡ thiết bị thất bại: $error');
    }
  }
}

final pushPreferenceProvider = AsyncNotifierProvider<PushPreference, bool>(
  PushPreference.new,
);
