import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/network/socket_client.dart';
import 'package:rent95/core/network/socket_events.dart';

void main() {
  group('IncomingMessage.fromJson', () {
    test('parses a full message payload', () {
      final m = IncomingMessage.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u1',
        'receiverId': 'u2',
        'messageType': 'text',
        'content': 'hi',
        'createdAt': '2025-01-01T10:00:00Z',
      });
      expect(m.id, 'm1');
      expect(m.conversationId, 'c1');
      expect(m.senderId, 'u1');
      expect(m.receiverId, 'u2');
      expect(m.type, 'text');
      expect(m.content, 'hi');
      expect(m.createdAt.toIso8601String(), '2025-01-01T10:00:00.000Z');
    });

    test('falls back to "type" when messageType missing (legacy)', () {
      final m = IncomingMessage.fromJson({
        'id': 'm2',
        'conversationId': 'c1',
        'senderId': 'u1',
        'receiverId': 'u2',
        'type': 'image',
        'mediaUrl': 'https://x/img.jpg',
        'createdAt': '2025-01-01T10:00:00Z',
      });
      expect(m.type, 'image');
      expect(m.content, isNull);
      expect(m.mediaUrl, 'https://x/img.jpg');
    });

    test('defaults to text when neither field present', () {
      final m = IncomingMessage.fromJson({
        'id': 'm',
        'conversationId': 'c',
        'senderId': 'a',
        'receiverId': 'b',
        'content': 'x',
        'createdAt': '2025-01-01T10:00:00Z',
      });
      expect(m.type, 'text');
    });
  });

  group('OrderUpdate.fromJson', () {
    test('extracts id and status from an order payload', () {
      final u = OrderUpdate.fromJson({
        'id': 'ord_1',
        'status': 'accepted',
        'orderNumber': 'R95-1',
        'totalAmount': 100,
      });
      expect(u.orderId, 'ord_1');
      expect(u.status, 'accepted');
      expect(u.raw!['orderNumber'], 'R95-1');
    });

    test('handles missing status', () {
      final u = OrderUpdate.fromJson({'id': 'ord_x'});
      expect(u.status, 'unknown');
    });
  });

  group('RealtimeNotification.fromJson', () {
    test('picks conversationId as entity id when present', () {
      final n = RealtimeNotification.fromJson({
        'type': 'message_received',
        'conversationId': 'c1',
        'messageId': 'm1',
      });
      expect(n.type, 'message_received');
      expect(n.entityId, 'c1');
    });

    test('falls back to orderId when conversationId absent', () {
      final n = RealtimeNotification.fromJson({
        'type': 'booking_accepted',
        'orderId': 'ord_9',
      });
      expect(n.entityId, 'ord_9');
    });

    test('defaults type to system', () {
      final n = RealtimeNotification.fromJson(<String, dynamic>{});
      expect(n.type, 'system');
    });
  });

  group('SocketEvents', () {
    test('names match backend contract exactly', () {
      // These strings are the wire contract with rent95-api. If a value
      // changes on either side, this test should fail as an early warning.
      expect(SocketEvents.joinConversation, 'join_conversation');
      expect(SocketEvents.leaveConversation, 'leave_conversation');
      expect(SocketEvents.typingStart, 'typing_start');
      expect(SocketEvents.typingStop, 'typing_stop');
      expect(SocketEvents.markRead, 'mark_read');
      expect(SocketEvents.joinOrderRoom, 'join_order_room');
      expect(SocketEvents.messageReceived, 'message_received');
      expect(SocketEvents.messageRead, 'message_read');
      expect(SocketEvents.typingStarted, 'typing_started');
      expect(SocketEvents.typingStopped, 'typing_stopped');
      expect(SocketEvents.orderUpdated, 'order_updated');
      expect(SocketEvents.bookingRequestReceived, 'booking_request_received');
      expect(SocketEvents.paymentUpdated, 'payment_updated');
      expect(SocketEvents.notificationReceived, 'notification_received');
    });
  });
}
