import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_background.dart';
import 'package:animal_locket/features/chat/domain/chat_repository.dart';
import 'package:animal_locket/features/chat/presentation/chat_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    _controller.clear();
    await ref
        .read(conversationControllerProvider(widget.conversationId).notifier)
        .sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(
      conversationControllerProvider(widget.conversationId),
    );
    final myId = ref.watch(authControllerProvider).profile?.publicId;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Trò chuyện'),
        ),
        body: SafeArea(
          child: value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Không thể tải tin nhắn.')),
            data: (data) => Column(
              children: [
                if (data.closedReason != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.danger.withValues(alpha: .12),
                    child: Text(
                      'Hội thoại đã đóng: ${data.closedReason}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: data.messages.length,
                    itemBuilder: (_, index) => _MessageBubble(
                      message: data.messages[index],
                      mine: data.messages[index].senderId == myId,
                    ),
                  ),
                ),
                if (data.actionError != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Tin chưa gửi được. Nội dung vẫn được giữ trên màn hình.',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: data.closedReason == null ? () {} : null,
                        icon: const Icon(Icons.photo_outlined),
                        tooltip: 'Gửi ảnh',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: data.closedReason == null,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: 'Nhắn tin…',
                            counterText: '',
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: data.closedReason == null ? _send : null,
                        icon: const Icon(Icons.send_rounded),
                        tooltip: 'Gửi tin nhắn',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Opacity(
      opacity: message.pending ? .65 : 1,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: message.failed
              ? AppColors.danger.withValues(alpha: .16)
              : mine
              ? AppColors.purple
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: message.type == ChatMessageType.image
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined),
                  SizedBox(width: 8),
                  Text('Ảnh'),
                ],
              )
            : Text(
                message.text ?? '',
                style: TextStyle(
                  color: mine && !message.failed ? Colors.white : AppColors.ink,
                ),
              ),
      ),
    ),
  );
}
