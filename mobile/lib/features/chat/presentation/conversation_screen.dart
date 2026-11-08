import 'dart:async';

import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_background.dart';
import 'package:animal_locket/features/chat/data/glyph_repository_impl.dart';
import 'package:animal_locket/features/chat/domain/chat_repository.dart';
import 'package:animal_locket/features/chat/domain/glyph.dart';
import 'package:animal_locket/features/chat/presentation/chat_controllers.dart';
import 'package:animal_locket/features/chat/presentation/glyph_controllers.dart';
import 'package:animal_locket/features/chat/presentation/widgets/glyph_composer_panel.dart';
import 'package:animal_locket/features/chat/presentation/widgets/glyph_message_bubble.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(conversationGlyphsProvider(widget.conversationId).notifier)
            .refresh(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(
      conversationControllerProvider(widget.conversationId),
    );
    final glyphs =
        ref
            .watch(conversationMessageGlyphsProvider(widget.conversationId))
            .value ??
        const <GlyphDefinition>[];
    final myId = ref.watch(authControllerProvider).profile?.publicId;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.conversationTitle),
        ),
        body: SafeArea(
          child: value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(l10n.messagesLoadError)),
            data: (data) {
              // Chat chỉ bằng ký hiệu: ẩn tin chữ/ảnh cũ (dữ liệu vẫn còn trên server).
              final messages = data.messages
                  .where((m) => m.type == ChatMessageType.glyph)
                  .toList();
              return Column(
                children: [
                  if (data.closedReason != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.danger.withValues(alpha: .12),
                      child: Text(
                        '${l10n.conversationClosed}: ${data.closedReason}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(child: Text(l10n.glyphComposerEmpty))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (_, index) => _MessageBubble(
                              message: messages[index],
                              mine: messages[index].senderId == myId,
                              dictionary: glyphs,
                              onRetry: () => ref
                                  .read(
                                    conversationControllerProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .retryMessage(messages[index]),
                            ),
                          ),
                  ),
                  if (data.actionError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        data.actionError is GlyphFeatureUnavailable
                            ? l10n.glyphFeatureWaitingBackend
                            : l10n.messageSendFailed,
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  GlyphComposerPanel(
                    conversationId: widget.conversationId,
                    enabled: data.closedReason == null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.dictionary,
    required this.onRetry,
  });
  final ChatMessage message;
  final bool mine;
  final List<GlyphDefinition> dictionary;
  final VoidCallback onRetry;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == ChatMessageType.image)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined),
                  SizedBox(width: 8),
                  Text('Ảnh'),
                ],
              )
            else if (message.type == ChatMessageType.glyph)
              GlyphMessageBubble(
                message: message,
                dictionary: dictionary,
                mine: mine,
              )
            else
              Text(
                message.text ?? '',
                style: TextStyle(
                  color: mine && !message.failed ? Colors.white : AppColors.ink,
                ),
              ),
            if (message.failed)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.retryMessage),
              ),
          ],
        ),
      ),
    ),
  );
}
