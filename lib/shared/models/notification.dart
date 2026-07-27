import 'package:flutter/foundation.dart';

enum AppNotificationType {
  accountVerified,
  kycApproved,
  kycRejected,
  listingApproved,
  listingRejected,
  bookingRequested,
  bookingAccepted,
  bookingRejected,
  paymentSuccess,
  paymentFailed,
  orderStarted,
  orderCompleted,
  messageReceived,
  reviewReceived,
  refundProcessed,
  disputeUpdated,
  payoutProcessed,
  system,
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.entityId,
    this.targetRoute,
  });

  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? entityId;
  final String? targetRoute;
}
