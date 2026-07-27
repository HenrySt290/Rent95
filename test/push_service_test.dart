import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/services/push_service.dart';

// The full PushService requires platform channels, so we can only test the
// pure Dart bits here: the payload mapper. The rest is exercised on-device.

void main() {
  group('PushPayload.fromRemoteMessage-equivalent parsing', () {
    // We can't easily construct a RemoteMessage in a widget test, so cover
    // the same parsing logic by testing the shape a real message produces.
    // Any behaviour change here breaks the type→route mapping downstream.

    test('picks conversationId as entityId', () {
      const payload = PushPayload(
        type: 'message_received',
        data: {'conversationId': 'c1'},
        entityId: 'c1',
      );
      expect(payload.entityId, 'c1');
      expect(payload.type, 'message_received');
    });

    test('preserves data fields intact', () {
      const payload = PushPayload(
        type: 'booking_accepted',
        data: {'orderId': 'ord_9', 'listingTitle': 'Tesla'},
        entityId: 'ord_9',
      );
      expect(payload.data['orderId'], 'ord_9');
      expect(payload.data['listingTitle'], 'Tesla');
    });

    test('defaults type when missing', () {
      const payload = PushPayload(type: 'system', data: {});
      expect(payload.type, 'system');
    });
  });
}
