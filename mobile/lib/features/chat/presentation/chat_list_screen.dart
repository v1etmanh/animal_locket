import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/chat/domain/chat_repository.dart';
import 'package:animal_locket/features/chat/presentation/chat_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(conversationsProvider);
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trò chuyện', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text(
            'Tin nhắn chỉ mở giữa bạn bè.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(conversationsProvider),
                child: const Text('Không tải được · Thử lại'),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Text(
                      'Chưa có cuộc trò chuyện nào.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _ConversationTile(conversation: items[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});
  final Conversation conversation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(chatProfileProvider(conversation.withPublicId));
    return GlassContainer(
      onTap: () => context.push('/chat/${conversation.id}'),
      child: profile.when(
        loading: () => const SizedBox(
          height: 58,
          child: Center(child: LinearProgressIndicator()),
        ),
        error: (_, _) => _row(context, conversation.withPublicId, null, null),
        data: (person) => _row(
          context,
          person.displayAlias,
          person.leadAnimal,
          person.avatar,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String alias,
    String? animal,
    String? avatar,
  ) => Row(
    children: [
      AnimalAvatar(avatar: avatar, leadAnimal: animal, size: 58),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alias, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              conversation.lastMessageAt == null
                  ? 'Bắt đầu trò chuyện'
                  : 'Tin nhắn gần đây',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      if (conversation.unread > 0)
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.danger,
          child: Text(
            '${conversation.unread}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
    ],
  );
}
