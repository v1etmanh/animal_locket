import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/profile/presentation/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(profileControllerProvider);
    return AppPage(
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Cài đặt',
        ),
      ],
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: ref.read(profileControllerProvider.notifier).refresh,
            child: const Text('Không tải được · Thử lại'),
          ),
        ),
        data: (data) => _ProfileContent(data: data),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.data});
  final ProfileData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Cài đặt',
        ),
      ),
      AnimalAvatar(
        avatar: data.profile.avatar,
        leadAnimal: data.profile.leadAnimal,
        size: 130,
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              data.profile.displayAlias,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          IconButton(
            onPressed: () => _editAlias(context, ref),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Đổi biệt danh',
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Thành viên ${data.profile.plan == AccountPlan.pro ? 'Pro' : 'Free'}',
        style: const TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _Stat(
              value: '${data.avatars.length}',
              label: 'Avatar sở hữu',
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Bộ sưu tập',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const SizedBox(height: 6),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Mỗi avatar chỉ thuộc về bạn, không ai khác có được.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 13,
        runSpacing: 13,
        children: [
          for (final owned in data.avatars)
            Tooltip(
              message:
                  AvatarLibraries.instance.animalName(owned.avatar) ??
                  owned.avatar,
              child: AnimalAvatar(avatar: owned.avatar, size: 72),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (data.profile.ageGroup == AgeGroup.adult &&
          data.profile.plan != AccountPlan.pro)
        OutlinedButton(
          onPressed: () => context.push('/pro'),
          child: const Text('Khám phá Animal Locket Pro'),
        ),
    ],
  );

  Future<void> _editAlias(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: data.profile.alias);
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi biệt danh'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Biệt danh'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (alias?.trim().isNotEmpty == true) {
      await ref.read(profileControllerProvider.notifier).updateAlias(alias!);
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => GlassContainer(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}
