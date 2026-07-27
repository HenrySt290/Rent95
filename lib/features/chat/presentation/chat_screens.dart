import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/models/message.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_providers.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).listConversations();
});

/// Live messages for a conversation. Uses a `StateNotifier` so we can add
/// optimistic sends and (later) socket-pushed messages without re-fetching.
final messagesProvider = StateNotifierProvider.autoDispose
    .family<MessagesController, AsyncValue<List<ChatMessage>>, String>(
  (ref, conversationId) => MessagesController(ref, conversationId),
);

class MessagesController extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  MessagesController(this._ref, this.conversationId)
      : super(const AsyncValue.loading()) {
    _load();
  }
  final Ref _ref;
  final String conversationId;

  Future<void> _load() async {
    try {
      final list = await _ref
          .read(chatRepositoryProvider)
          .listMessages(conversationId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final current = state.value ?? const <ChatMessage>[];

    // Optimistic tempMsg — replaced when the real send resolves.
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

    try {
      final sent = await _ref
          .read(chatRepositoryProvider)
          .sendMessage(conversationId, text.trim());
      state = AsyncValue.data([
        for (final m in state.value ?? const <ChatMessage>[])
          if (m.id == tempId) sent else m,
      ]);
    } catch (_) {
      // Rollback the optimistic message on failure.
      state = AsyncValue.data([
        for (final m in state.value ?? const <ChatMessage>[])
          if (m.id != tempId) m,
      ]);
    }
  }
}

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
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
                                color: AppColors.primary, fontWeight: FontWeight.w700),
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
                const Text('Online',
                    style: TextStyle(fontSize: 11, color: AppColors.success)),
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
              itemCount: list.length,
              itemBuilder: (_, i) {
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



