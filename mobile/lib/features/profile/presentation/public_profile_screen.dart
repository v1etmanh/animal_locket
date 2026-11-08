import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/chat/data/chat_repository_impl.dart';
import 'package:animal_locket/features/friends/data/friends_repository_impl.dart';
import 'package:animal_locket/features/friends/domain/friends_repository.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final publicProfileProvider = FutureProvider.family<PublicProfile, String>(
  (ref, id) => ref.watch(userRepositoryProvider).publicProfile(id),
);

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.publicId});
  final String publicId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(publicProfileProvider(publicId));
    return AppPage(
      title: 'Hồ sơ',
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Không thể tải hồ sơ.')),
        data: (profile) => GlassContainer(
          borderRadius: 34,
          child: Column(
            children: [
              AnimalAvatar(
                avatar: profile.avatar,
                leadAnimal: profile.leadAnimal,
                size: 130,
              ),
              const SizedBox(height: 18),
              Text(
                profile.displayAlias,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Hồ sơ ẩn danh',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _chat(context, ref),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Nhắn tin'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(friendsRepositoryProvider).remove(publicId);
                  if (context.mounted) context.pop();
                },
                child: const Text('Huỷ kết bạn'),
              ),
              const Divider(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _report(context, ref),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Báo cáo'),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => _block(context, ref),
                    icon: const Icon(Icons.block),
                    label: const Text('Chặn'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chat(BuildContext context, WidgetRef ref) async {
    final conversation = await ref
        .read(chatRepositoryProvider)
        .createConversation(publicId);
    if (context.mounted) context.push('/chat/${conversation.id}');
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chặn người này?'),
        content: const Text(
          'Hai người sẽ không thể tìm thấy hoặc nhắn tin cho nhau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Chặn'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref.read(safetyRepositoryProvider).block(publicId);
      if (context.mounted) context.pop();
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Báo cáo'),
        content: TextField(
          controller: details,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Chi tiết'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
    final text = details.text.trim();
    details.dispose();
    if (submit == true) {
      await ref
          .read(safetyRepositoryProvider)
          .report(
            targetType: ReportTarget.user,
            targetPublicId: publicId,
            reason: 'USER_REPORT',
            details: text.isEmpty ? null : text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo.')));
      }
    }
  }
}
