import 'dart:async';

import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/config/backend_mode.dart';
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
  final _controller = TextEditingController();
  var _glyphMode = false;

  @override
  void initState() {
    super.initState();
    _glyphMode = ref.read(backendModeProvider) == BackendMode.demo;
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
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(
      conversationControllerProvider(widget.conversationId),
    );
    final glyphs =
        ref.watch(conversationGlyphsProvider(widget.conversationId)).value ??
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
            data: (data) => Column(
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
                  child: data.messages.isEmpty
                      ? Center(child: Text(l10n.glyphComposerEmpty))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: data.messages.length,
                          itemBuilder: (_, index) => _MessageBubble(
                            message: data.messages[index],
                            mine: data.messages[index].senderId == myId,
                            dictionary: glyphs,
                            onRetry: () => ref
                                .read(
                                  conversationControllerProvider(
                                    widget.conversationId,
                                  ).notifier,
                                )
                                .retryMessage(data.messages[index]),
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
                if (_glyphMode)
                  GlyphComposerPanel(
                    conversationId: widget.conversationId,
                    enabled: data.closedReason == null,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: l10n.sendPhoto,
                          child: IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            onPressed: data.closedReason == null ? () {} : null,
                            icon: const Icon(Icons.photo_outlined),
                            tooltip: l10n.sendPhoto,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.glyphModeOpen,
                          child: IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            onPressed: data.closedReason == null
                                ? () => setState(() => _glyphMode = true)
                                : null,
                            icon: const Icon(Icons.gesture_rounded),
                            tooltip: l10n.glyphModeOpen,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: data.closedReason == null,
                            maxLength: 2000,
                            decoration: InputDecoration(
                              hintText: l10n.messageHint,
                              counterText: '',
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.sendMessage,
                          child: IconButton.filled(
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            onPressed: data.closedReason == null ? _send : null,
                            icon: const Icon(Icons.send_rounded),
                            tooltip: l10n.sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_glyphMode)
                  SizedBox(
                    height: 48,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _glyphMode = false),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: Text(l10n.glyphModeClose),
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
