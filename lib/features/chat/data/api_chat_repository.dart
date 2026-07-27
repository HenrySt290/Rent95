import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../shared/models/message.dart';
import 'chat_repository.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._dio, this._currentUserId);
  final Dio _dio;
  final String _currentUserId;

  @override
  Future<List<Conversation>> listConversations() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/conversations');
    return decodeList(res, _conversationFromApi);
  }

  @override
  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/conversations/$conversationId/messages',
    );
    return decodeList(res, _messageFromApi);
  }

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/conversations/$conversationId/messages',
      data: {'content': text, 'type': 'text'},
    );
    return decodeObject(res, _messageFromApi);
  }

  @override
  Future<Conversation> openWithSeller({
    required String sellerId,
    String? productId,
    String? orderId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/conversations',
      data: <String, dynamic>{
        'sellerId': sellerId,
        if (productId != null) 'productId': productId,
        if (orderId != null) 'orderId': orderId,
      },
    );
    return decodeObject(res, _conversationFromApi);
  }

  // -----------------------------------------------------------------

  Conversation _conversationFromApi(Map<String, dynamic> j) {
    final buyer = (j['buyer'] as Map?)?.cast<String, dynamic>();
    final seller = (j['seller'] as Map?)?.cast<String, dynamic>();
    final iAmBuyer = (buyer?['id'] as String?) == _currentUserId;
    final other = iAmBuyer ? seller : buyer;

    return Conversation(
      id: j['id'] as String,
      buyerId: j['buyerId'] as String,
      sellerId: j['sellerId'] as String,
      otherUserName: (other?['fullName'] as String?) ?? 'Rent95 user',
      otherUserAvatarUrl: other?['profileImageUrl'] as String?,
      productId: j['productId'] as String?,
      orderId: j['orderId'] as String?,
      lastMessage: j['lastMessage'] as String?,
      updatedAt: j['lastMessageAt'] != null
          ? DateTime.parse(j['lastMessageAt'] as String)
          : DateTime.parse(j['createdAt'] as String),
    );
  }

  ChatMessage _messageFromApi(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        type: _messageTypeFromApi(j['messageType'] as String? ?? 'text'),
        content: j['content'] as String?,
        mediaUrl: j['mediaUrl'] as String?,
        isRead: (j['isRead'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  MessageType _messageTypeFromApi(String v) {
    switch (v) {
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}
