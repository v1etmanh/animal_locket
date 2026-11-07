import 'dart:async';

import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/features/chat/data/chat_realtime_service.dart';
import 'package:animal_locket/features/chat/data/chat_repository_impl.dart';
import 'package:animal_locket/features/chat/domain/chat_repository.dart';
import 'package:animal_locket/features/profile/data/user_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final conversationsProvider = FutureProvider<List<Conversation>>(
  (ref) => ref.watch(chatRepositoryProvider).conversations(),
);
final chatProfileProvider = FutureProvider.family<PublicProfile, String>(
  (ref, publicId) => ref.watch(userRepositoryProvider).publicProfile(publicId),
);

class ConversationState {
  const ConversationState({
    required this.messages,
    this.closedReason,
    this.actionError,
  });
  final List<ChatMessage> messages;
  final String? closedReason;
  final Object? actionError;
  ConversationState copyWith({
    List<ChatMessage>? messages,
    String? closedReason,
    Object? actionError,
  }) => ConversationState(
    messages: messages ?? this.messages,
    closedReason: closedReason ?? this.closedReason,
    actionError: actionError,
  );
}

class _PendingMessage {
  _PendingMessage(this.tempId, this.text, this.retries);
  final String tempId;
  final String text;
  final int retries;
}

class ConversationController extends AsyncNotifier<ConversationState> {
  ConversationController(this.conversationId);
  final String conversationId;
  final _uuid = const Uuid();
  final Map<String, _PendingMessage> _pending = {};
  final Map<String, Timer> _timers = {};
  StreamSubscription<Map<String, dynamic>>? _events;

  @override
  Future<ConversationState> build() async {
    final realtime = ref.watch(chatRealtimeProvider);
    _events = realtime.events.listen(_onEvent);
    ref.onDispose(() {
      _events?.cancel();
      for (final timer in _timers.values) {
        timer.cancel();
      }
    });
    final messages = await ref
        .read(chatRepositoryProvider)
        .messages(conversationId);
    unawaited(ref.read(chatRepositoryProvider).markRead(conversationId));
    realtime.send({'type': 'read', 'conversationId': conversationId});
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ConversationState(messages: messages);
  }

  Future<void> sendText(String text) async {
    final normalized = text.trim();
    final current = state.value;
    if (current == null ||
        normalized.isEmpty ||
        normalized.length > 2000 ||
        current.closedReason != null) {
      return;
    }
    final me = ref.read(authControllerProvider).profile?.publicId ?? '';
    final tempId = 'local-${_uuid.v4()}';
    final optimistic = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: me,
      type: ChatMessageType.text,
      text: normalized,
      createdAt: DateTime.now().toUtc(),
      pending: true,
    );
    state = AsyncData(
      current.copyWith(messages: [...current.messages, optimistic]),
    );
    final realtime = ref.read(chatRealtimeProvider);
    if (realtime.state != ChatConnectionState.connected) {
      await _sendRest(tempId, normalized);
      return;
    }
    _sendSocket(tempId, normalized, 0);
  }

  void _sendSocket(String tempId, String text, int retries) {
    final clientId = _uuid.v4();
    _pending[clientId] = _PendingMessage(tempId, text, retries);
    ref.read(chatRealtimeProvider).send({
      'type': 'send',
      'conversationId': conversationId,
      'text': text,
      'clientId': clientId,
    });
    _timers[clientId] = Timer(const Duration(seconds: 10), () async {
      final pending = _pending.remove(clientId);
      _timers.remove(clientId);
      if (pending == null) return;
      if (pending.retries == 0 &&
          ref.read(chatRealtimeProvider).state ==
              ChatConnectionState.connected) {
        _sendSocket(pending.tempId, pending.text, 1);
      } else {
        await _sendRest(pending.tempId, pending.text);
      }
    });
  }

  Future<void> _sendRest(String tempId, String text) async {
    try {
      final saved = await ref
          .read(chatRepositoryProvider)
          .sendText(conversationId, text);
      _replace(tempId, saved);
    } catch (error) {
      _replace(tempId, _find(tempId)?.copyWith(pending: false, failed: true));
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(actionError: error));
      }
    }
  }

  ChatMessage? _find(String id) =>
      state.value?.messages.where((item) => item.id == id).firstOrNull;
  void _replace(String id, ChatMessage? replacement) {
    if (replacement == null) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: current.messages
            .map((item) => item.id == id ? replacement : item)
            .toList(),
      ),
    );
  }

  void _onEvent(Map<String, dynamic> frame) {
    final type = frame['type'];
    final data = (frame['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (type == 'message' &&
        data['conversationId'].toString() == conversationId) {
      final message = ChatMessage.fromJson(data);
      final current = state.value;
      if (current != null &&
          !current.messages.any((item) => item.id == message.id)) {
        state = AsyncData(
          current.copyWith(
            messages: [...current.messages, message]
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          ),
        );
      }
    } else if (type == 'ack') {
      final clientId = data['clientId'] as String?;
      if (clientId == null) return;
      final pending = _pending.remove(clientId);
      _timers.remove(clientId)?.cancel();
      if (pending != null) {
        final optimistic = _find(pending.tempId);
        if (optimistic != null) {
          _replace(
            pending.tempId,
            optimistic.copyWith(
              id: data['messageId'].toString(),
              pending: false,
            ),
          );
        }
      }
    } else if (type == 'closed' &&
        data['conversationId'].toString() == conversationId) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(closedReason: data['reason'] as String? ?? 'CLOSED'),
        );
      }
    } else if (type == 'error') {
      final clientId = data['clientId'] as String?;
      final pending = clientId == null ? null : _pending.remove(clientId);
      if (clientId != null) _timers.remove(clientId)?.cancel();
      if (pending != null) {
        final item = _find(pending.tempId);
        if (item != null) {
          _replace(item.id, item.copyWith(pending: false, failed: true));
        }
      }
    }
  }
}

final conversationControllerProvider =
    AsyncNotifierProvider.family<
      ConversationController,
      ConversationState,
      String
    >(ConversationController.new);
