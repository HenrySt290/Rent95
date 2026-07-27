import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import 'push_service.dart';

/// Buffers push-tap payloads until [attach] is called with a live GoRouter,
/// then drains the buffer + subscribes for future taps.
///
/// This solves a real bootstrap problem: a notification tap that *launched*
/// the app from a cold-terminated state arrives on `PushService.taps$` in
/// the first microtask, before any widget (including GoRouter) has been
/// built. Without this buffer we'd drop the deep link.
///
/// Consumers only need to know two things:
///
///   1. Create the provider once during app boot (Riverpod does that for us).
///   2. Call `router.attach(goRouter)` from inside a `Consumer` that sits
///      *below* the MaterialApp.router so the router is guaranteed live.
class NotificationRouter {
  NotificationRouter(this._ref) {
    _sub = _ref.read(pushServiceProvider).taps$.listen(_onTap);
  }

  final Ref _ref;
  StreamSubscription<PushPayload>? _sub;
  GoRouter? _router;

  /// Payloads that arrived before the router was ready.
  final List<PushPayload> _pending = [];

  void attach(GoRouter router) {
    _router = router;
    // Drain any payloads that arrived during boot.
    while (_pending.isNotEmpty) {
      final p = _pending.removeAt(0);
      _navigate(p);
    }
  }

  void _onTap(PushPayload payload) {
    if (_router == null) {
      _pending.add(payload);
      return;
    }
    _navigate(payload);
  }

  void _navigate(PushPayload payload) {
    final route = routeFor(payload);
    if (route == null) return;
    _router!.push(route);
  }

  /// Map notification `type` + `entityId` → in-app route.
  ///
  /// Public + `@visibleForTesting` so tests can assert the mapping without
  /// having to instantiate the full router. Kept in one place so adding a
  /// new push type only requires one edit.
  ///
  /// See `AppNotificationType` in `shared/models/notification.dart` for the
  /// canonical list of types the backend can send.
  @visibleForTesting
  String? routeFor(PushPayload p) {
    switch (p.type) {
      case 'message_received':
        final convId = p.entityId ?? p.data['conversationId'];
        return convId == null ? AppRoutes.messages : AppRoutes.chatDetailFor(convId);

      case 'booking_requested':
      case 'booking_accepted':
      case 'booking_rejected':
      case 'order_started':
      case 'order_completed':
      case 'payment_success':
      case 'payment_failed':
      case 'refund_processed':
        final orderId = p.entityId ?? p.data['orderId'];
        return orderId == null ? AppRoutes.buyerOrders : AppRoutes.orderDetailFor(orderId);

      case 'listing_approved':
      case 'listing_rejected':
        final listingId = p.entityId ?? p.data['listingId'];
        return listingId == null ? AppRoutes.sellerListings : AppRoutes.listingDetailFor(listingId);

      case 'review_received':
        return AppRoutes.reviews;

      case 'kyc_approved':
      case 'kyc_rejected':
      case 'account_verified':
      case 'payout_processed':
        return AppRoutes.notifications;

      default:
        return AppRoutes.notifications;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

final notificationRouterProvider = Provider<NotificationRouter>((ref) {
  final router = NotificationRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});
