import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/services/notification_router.dart';
import 'package:rent95/core/services/push_service.dart';

/// We build the [NotificationRouter] with a real [ProviderContainer] but
/// never call [PushService.instance.init()], so nothing platform-level runs.
/// The subscription to `taps$` just sees an empty broadcast stream — fine.
NotificationRouter _newRouter() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(notificationRouterProvider);
}

void main() {
  group('NotificationRouter.routeFor', () {
    late NotificationRouter router;

    setUp(() {
      router = _newRouter();
    });

    test('message_received with entityId → /messages/<id>', () {
      expect(
        router.routeFor(const PushPayload(
          type: 'message_received',
          entityId: 'conv_1',
          data: {},
        )),
        '/messages/conv_1',
      );
    });

    test('message_received without entityId → /messages', () {
      expect(
        router.routeFor(const PushPayload(type: 'message_received', data: {})),
        '/messages',
      );
    });

    test('booking_accepted → /orders/<id>', () {
      expect(
        router.routeFor(const PushPayload(
          type: 'booking_accepted',
          entityId: 'ord_9',
          data: {},
        )),
        '/orders/ord_9',
      );
    });

    test('all order-family types resolve to /orders/<id>', () {
      const orderTypes = [
        'booking_requested',
        'booking_accepted',
        'booking_rejected',
        'order_started',
        'order_completed',
        'payment_success',
        'payment_failed',
        'refund_processed',
      ];
      for (final t in orderTypes) {
        expect(
          router.routeFor(PushPayload(type: t, entityId: 'ord_1', data: const {})),
          '/orders/ord_1',
          reason: 'type=$t should route to order detail',
        );
      }
    });

    test('listing_approved / rejected → /listing/<id>', () {
      for (final t in const ['listing_approved', 'listing_rejected']) {
        expect(
          router.routeFor(PushPayload(type: t, entityId: 'lst_1', data: const {})),
          '/listing/lst_1',
        );
      }
    });

    test('review_received → /profile/reviews', () {
      expect(
        router.routeFor(const PushPayload(type: 'review_received', data: {})),
        '/profile/reviews',
      );
    });

    test('unknown types fall back to /notifications', () {
      expect(
        router.routeFor(const PushPayload(type: 'a_new_type', data: {})),
        '/notifications',
      );
      expect(
        router.routeFor(const PushPayload(type: 'anything', data: {})),
        '/notifications',
      );
    });

    test('picks entityId from data map when top-level is null', () {
      expect(
        router.routeFor(const PushPayload(
          type: 'message_received',
          data: {'conversationId': 'from_data'},
        )),
        '/messages/from_data',
      );
      expect(
        router.routeFor(const PushPayload(
          type: 'booking_accepted',
          data: {'orderId': 'from_data'},
        )),
        '/orders/from_data',
      );
    });
  });
}
