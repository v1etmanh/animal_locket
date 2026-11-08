import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/discovery/data/discovery_repository_impl.dart';
import 'package:animal_locket/features/friends/data/friends_repository_impl.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:animal_locket/features/profile/presentation/profile_controller.dart';
import 'package:animal_locket/features/profile/presentation/theme_picker.dart';
import 'package:animal_locket/core/widgets/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final blockedUsersProvider = FutureProvider<List<PublicProfile>>(
  (ref) => ref.watch(safetyRepositoryProvider).blocked(),
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _discoverable;
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).value?.profile;
    final discoverable = _discoverable ?? profile?.discoverable ?? false;
    final blocked = ref.watch(blockedUsersProvider);
    return AppPage(
      title: 'Cài đặt và riêng tư',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ThemePicker(),
          const SizedBox(height: 24),
          GlassContainer(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: discoverable,
              onChanged: _busy ? null : _setDiscovery,
              title: const Text(
                'Cho phép khám phá',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Tắt để xoá vị trí và dừng xuất hiện trong bộ thẻ.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Đã chặn'),
          const SizedBox(height: 10),
          blocked.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(blockedUsersProvider),
              child: const Text('Không tải được · Thử lại'),
            ),
            data: (items) => items.isEmpty
                ? const Text(
                    'Chưa chặn ai.',
                    style: TextStyle(color: AppColors.muted),
                  )
                : Column(
                    children: [
                      for (final person in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassContainer(
                            child: Row(
                              children: [
                                AnimalAvatar(
                                  avatar: person.avatar,
                                  leadAnimal: person.leadAnimal,
                                  size: 46,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(person.displayAlias)),
                                TextButton(
                                  onPressed: () => _unblock(person.publicId),
                                  child: const Text('Bỏ chặn'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _busy ? null : _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xoá tài khoản'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDiscovery(bool enabled) async {
    setState(() {
      _busy = true;
      _discoverable = enabled;
    });
    try {
      await ref.read(userRepositoryProvider).update(discoverable: enabled);
      if (!enabled) {
        await ref.read(discoveryRepositoryProvider).deleteLocation();
      }
      ref.invalidate(profileControllerProvider);
    } catch (_) {
      if (mounted) setState(() => _discoverable = !enabled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unblock(String publicId) async {
    await ref.read(safetyRepositoryProvider).unblock(publicId);
    ref.invalidate(blockedUsersProvider);
  }

  Future<void> _confirmDelete() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá tài khoản?'),
        content: const Text(
          'Ảnh, tin nhắn và hồ sơ sẽ bị xoá. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ tài khoản'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => const TextInputDialog(
        title: 'Xác nhận lần cuối',
        label: 'Nhập XOÁ để xác nhận',
        confirmLabel: 'Xoá vĩnh viễn',
      ),
    );
    final second = typed?.trim().toUpperCase() == 'XOÁ';
    if (!second || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(userRepositoryProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
