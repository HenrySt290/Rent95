import '../../../shared/models/message.dart';
import '../../../shared/services/mock_store.dart';
import 'chat_repository.dart';

class MockChatRepository implements ChatRepository {
  MockChatRepository(this._store);
  final MockStore _store;

  @override
  Future<List<Conversation>> listConversations() async {
    return List.unmodifiable(_store.conversations);
  }

  @override
  Future<List<ChatMessage>> listMessages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_store.messages[conversationId] ?? const <ChatMessage>[]);
  }

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text) {
    return _store.sendMessage(conversationId, text);
  }

  @override
  Future<Conversation> openWithSeller({
    required String sellerId,
    String? productId,
    String? orderId,
  }) async {
    // Reuse the first existing conversation for demo purposes.
    final existing = _store.conversations
        .where((c) => c.sellerId == sellerId)
        .firstOrNull;
    if (existing != null) return existing;
    return _store.conversations.first;
  }
}
