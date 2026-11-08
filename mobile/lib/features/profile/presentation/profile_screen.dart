import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/core/widgets/text_input_dialog.dart';
import 'package:animal_locket/features/feed/presentation/posts_grid.dart';
import 'package:animal_locket/features/friends/presentation/friends_controller.dart';
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
      const _FriendsStrip(),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Ảnh của tôi',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const SizedBox(height: 12),
      PostsGrid(
        publicId: data.profile.publicId,
        mine: true,
        emptyText: 'Bạn chưa đăng ảnh nào.',
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
    final alias = await showDialog<String>(
      context: context,
      builder: (_) => TextInputDialog(
        title: 'Đổi biệt danh',
        label: 'Biệt danh',
        confirmLabel: 'Lưu',
        initialText: data.profile.alias ?? '',
        maxLength: 20, // server: 3–20 ký tự
      ),
    );
    if (alias == null ||
        alias.trim().isEmpty ||
        alias.trim() == data.profile.alias) {
      return;
    }
    try {
      await ref.read(profileControllerProvider.notifier).updateAlias(alias);
    } on ApiProblem catch (problem) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messageForApiCode(problem.code, status: problem.status),
            ),
          ),
        );
      }
    }
  }
}

/// Hàng avatar bạn bè cuộn ngang; chạm một người để mở trang của họ.
class _FriendsStrip extends ConsumerWidget {
  const _FriendsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsControllerProvider);
    final count = friends.value?.friends.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                count == null ? 'Bạn bè' : 'Bạn bè ($count)',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/friends'),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        friends.when(
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(friendsControllerProvider),
            child: const Text('Không tải được bạn bè · Thử lại'),
          ),
          data: (data) => data.friends.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chưa có bạn bè nào.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/discover'),
                        child: const Text('Tìm bạn'),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.friends.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final person = data.friends[index];
                      return Semantics(
                        button: true,
                        label: 'Mở trang của ${person.displayAlias}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/user/${person.publicId}'),
                          child: SizedBox(
                            width: 76,
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    AnimalAvatar(
                                      avatar: person.avatar,
                                      leadAnimal: person.leadAnimal,
                                      size: 64,
                                    ),
                                    if (data.online[person.publicId] == true)
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: AppColors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  person.displayAlias,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
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
