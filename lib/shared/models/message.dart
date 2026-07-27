import 'package:flutter/foundation.dart';

enum MessageType { text, image, system }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.content,
    this.mediaUrl,
    this.isRead = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final bool isRead;
  final DateTime createdAt;
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.otherUserName,
    required this.updatedAt,
    this.otherUserAvatarUrl,
    this.productId,
    this.orderId,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String? productId;
  final String? orderId;
  final String? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
}
