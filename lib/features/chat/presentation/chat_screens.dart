import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/network/socket_events.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/models/message.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_providers.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).listConversations();
});

/// Live messages for a conversation, blended from two sources:
///
///   1. **REST** — initial page fetched via `ChatRepository.listMessages`.
///   2. **Socket** — every `message_received` event for this conversation is
///      pushed on top of the existing list.
///
/// Optimistic sends are added immediately with a temp id and reconciled with
/// the persisted record when the POST returns (or the socket echoes it back —
/// whichever wins the race first).
final messagesProvider = StateNotifierProvider.autoDispose
    .family<MessagesController, AsyncValue<List<ChatMessage>>, String>(
  (ref, conversationId) => MessagesController(ref, conversationId),
);

class MessagesController extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  MessagesController(this._ref, this.conversationId)
      : super(const AsyncValue.loading()) {
    _load();
    _subscribeToSocket();
    _joinRoom();
  }

  final Ref _ref;
  final String conversationId;

  StreamSubscription<IncomingMessage>? _messageSub;
  StreamSubscription<SocketStatus>? _statusSub;
  Timer? _typingTimer;

  Future<void> _load() async {
    try {
      final list = await _ref.read(chatRepositoryProvider).listMessages(conversationId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _joinRoom() {
    final client = _ref.read(socketClientProvider);
    if (client.isConnected) {
      client.joinConversation(conversationId);
    } else {
      // If the socket isn't up yet (still connecting on cold start), rejoin
      // as soon as it becomes connected.
      _statusSub = client.status$.listen((status) {
        if (status == SocketStatus.connected) {
          client.joinConversation(conversationId);
        }
      });
    }
  }

  void _subscribeToSocket() {
    _messageSub = _ref.read(socketClientProvider).messages$.listen((msg) {
      if (msg.conversationId != conversationId) return;

      final me = _ref.read(authControllerProvider).user?.id;
      if (msg.senderId == me) {
        // Server echoed back our own send. Try to reconcile the temp message
        // if it's still in state; otherwise no-op (we'll have replaced it
        // via the REST response already).
        _reconcileOwnSend(msg);
        return;
      }
      _append(_incomingToDomain(msg));
    });
  }

  ChatMessage _incomingToDomain(IncomingMessage m) => ChatMessage(
        id: m.id,
        conversationId: m.conversationId,
        senderId: m.senderId,
        type: switch (m.type) {
          'image' => MessageType.image,
          'system' => MessageType.system,
          _ => MessageType.text,
        },
        content: m.content,
        mediaUrl: m.mediaUrl,
        createdAt: m.createdAt,
      );

  void _append(ChatMessage msg) {
    final current = state.value ?? const <ChatMessage>[];
    // De-dup: if we've already got this exact id, skip. Otherwise append and
    // keep list sorted by time (defensive — should already be sorted).
    if (current.any((m) => m.id == msg.id)) return;
    final next = [...current, msg]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = AsyncValue.data(next);
  }

  void _reconcileOwnSend(IncomingMessage msg) {
    final current = state.value ?? const <ChatMessage>[];
    // Find a temp message with matching content+sender that's within a
    // short window of the server's timestamp. Replace it with the real one.
    final match = current.indexWhere((m) =>
        m.id.startsWith('temp_') &&
        m.senderId == msg.senderId &&
        m.content == msg.content);
    if (match == -1) {
      _append(_incomingToDomain(msg));
      return;
    }
    final next = List<ChatMessage>.from(current)..[match] = _incomingToDomain(msg);
    state = AsyncValue.data(next);
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final current = state.value ?? const <ChatMessage>[];

    // Optimistic tempMsg — replaced when the send resolves or the socket echoes.
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final me = _ref.read(authControllerProvider).user?.id ?? 'me';
    final optimistic = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: me,
      type: MessageType.text,
      content: text.trim(),
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data([...current, optimistic]);

    // Tell the server we stopped typing (send implies not typing).
    _ref.read(socketClientProvider).stopTyping(conversationId);

    try {
      final sent = await _ref.read(chatRepositoryProvider).sendMessage(conversationId, text.trim());
      // Swap temp → real, unless the socket already did it.
      final currentAfter = state.value ?? const <ChatMessage>[];
      state = AsyncValue.data([
        for (final m in currentAfter)
          if (m.id == tempId) sent else m,
      ]);
    } catch (_) {
      // Rollback the optimistic message on failure.
      final currentAfter = state.value ?? const <ChatMessage>[];
      state = AsyncValue.data([for (final m in currentAfter) if (m.id != tempId) m]);
    }
  }

  /// Called on every keystroke — debounces "start typing" and schedules a
  /// "stop typing" 3 s after the last press.
  void reportTyping() {
    _ref.read(socketClientProvider).startTyping(conversationId);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _ref.read(socketClientProvider).stopTyping(conversationId);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageSub?.cancel();
    _statusSub?.cancel();
    // Best-effort tell the server we've left this room.
    try {
      _ref.read(socketClientProvider).leaveConversation(conversationId);
    } catch (_) {}
    super.dispose();
  }
}

/// Emits whether the *other* party in this conversation is currently typing.
final isOtherTypingProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, conversationId) {
  final client = ref.watch(socketClientProvider);
  final me = ref.watch(authControllerProvider).user?.id;
  return client.typing$
      .where((e) => e.conversationId == conversationId && e.userId != me)
      .map((e) => e.typing);
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    // Refresh the list whenever the socket pushes a new message, so
    // "last message" + unread badges stay live without polling.
    ref.watch(_conversationsAutoRefresher);

    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (convs) => convs.isEmpty
              ? const EmptyStateView(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  message: 'Message a seller from any listing to start chatting.',
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(conversationsProvider);
                    await ref.read(conversationsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: convs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final c = convs[i];
                      return ListTile(
                        onTap: () => context.push(AppRoutes.chatDetailFor(c.id)),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            c.otherUserName.characters.first,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(c.otherUserName,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          c.lastMessage ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Formatters.relative(c.updatedAt),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            if (c.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('${c.unreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

/// Side-effect provider that invalidates the conversations list whenever a
/// message arrives via socket. Watched but not awaited by [ChatListScreen].
final _conversationsAutoRefresher = Provider.autoDispose<void>((ref) {
  final client = ref.watch(socketClientProvider);
  final sub = client.messages$.listen((_) {
    ref.invalidate(conversationsProvider);
  });
  ref.onDispose(sub.cancel);
});

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final other = ref.watch(conversationsProvider).maybeWhen(
          data: (list) => list
              .where((c) => c.id == widget.conversationId)
              .map((c) => c.otherUserName)
              .firstOrNull,
          orElse: () => null,
        );
    final isTyping =
        ref.watch(isOtherTypingProvider(widget.conversationId)).valueOrNull ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (other ?? '?').characters.first,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(other ?? 'Chat',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                _PresenceLine(isTyping: isTyping),
              ],
            ),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) => ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: list.length + (isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (isTyping && i == list.length) {
                  return const _TypingBubble();
                }
                final m = list[i];
                final mine = m.senderId == currentUserId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                      border: mine ? null : Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(m.content ?? '',
                            style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.time(m.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: mine
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file)),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => ref
                      .read(messagesProvider(widget.conversationId).notifier)
                      .reportTyping(),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final text = _controller.text;
                  _controller.clear();
                  await ref
                      .read(messagesProvider(widget.conversationId).notifier)
                      .send(text);
                },
                icon: const Icon(Icons.send, color: AppColors.primary),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PresenceLine extends ConsumerWidget {
  const _PresenceLine({required this.isTyping});
  final bool isTyping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isTyping) {
      return const Text('typing…',
          style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500));
    }
    final status = ref.watch(socketStatusProvider).valueOrNull ?? SocketStatus.disconnected;
    switch (status) {
      case SocketStatus.connected:
        return const Text('Online',
            style: TextStyle(fontSize: 11, color: AppColors.success));
      case SocketStatus.connecting:
      case SocketStatus.reconnecting:
        return const Text('Reconnecting…',
            style: TextStyle(fontSize: 11, color: AppColors.warning));
      case SocketStatus.disconnected:
        return const Text('Offline',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
    }
  }
}

/// Three-dot animated typing indicator bubble.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_c.value + i * 0.15) % 1.0;
                final opacity = (0.35 + 0.65 * (1 - (t - 0.5).abs() * 2)).clamp(0.2, 1.0);
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
