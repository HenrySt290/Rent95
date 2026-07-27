import '../../../shared/models/message.dart';

abstract class ChatRepository {
  Future<List<Conversation>> listConversations();

  Future<List<ChatMessage>> listMessages(String conversationId);

  Future<ChatMessage> sendMessage(String conversationId, String text);

  /// Create (or fetch) a conversation with a seller about a listing.
  Future<Conversation> openWithSeller({
    required String sellerId,
    String? productId,
    String? orderId,
  });
}
