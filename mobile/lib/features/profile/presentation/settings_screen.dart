import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/widgets/album/paper_button.dart';
import 'package:animal_locket/core/widgets/album/paper_list.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/features/discovery/data/discovery_repository_impl.dart';
import 'package:animal_locket/features/friends/data/friends_repository_impl.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:animal_locket/features/profile/presentation/profile_controller.dart';
import 'package:animal_locket/features/profile/presentation/language_picker.dart';
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
    final p = context.album;
    return AppPage(
      title: 'Cài đặt và riêng tư',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ThemePicker(),
          const SizedBox(height: 24),
          const LanguagePicker(),
          const SizedBox(height: 24),
          PaperSheet(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
            error: (_, _) => Align(
              alignment: Alignment.centerLeft,
              child: PaperButton.tape(
                label: 'Không tải được · Thử lại',
                onPressed: () => ref.invalidate(blockedUsersProvider),
              ),
            ),
            data: (items) => items.isEmpty
                ? Text('Chưa chặn ai.', style: TextStyle(color: p.muted))
                : PaperSheet(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          for (final (i, person) in items.indexed) ...[
                            if (i > 0) const DashedDivider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  MiniPolaroidAvatar(
                                    avatar: person.avatar,
                                    leadAnimal: person.leadAnimal,
                                    index: i,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      person.displayAlias,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  PaperButton.tape(
                                    label: 'Bỏ chặn',
                                    onPressed: () => _unblock(person.publicId),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.center,
            child: PaperButton.tape(
              label: 'Đăng xuất',
              icon: AlbumIcons.logout,
              onPressed: _busy
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: p.danger),
              onPressed: _busy ? null : _confirmDelete,
              icon: AlbumIcon(
                AlbumIcons.trash,
                size: 18,
                color: _busy ? p.muted : p.danger,
              ),
              label: const Text('Xoá tài khoản'),
            ),
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
            style: FilledButton.styleFrom(
              backgroundColor: context.album.danger,
            ),
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
