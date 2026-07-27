import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../shared/models/notification.dart';
import 'notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<AppNotification>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/notifications');
    return decodeList(res, _fromApi);
  }

  @override
  Future<void> markRead(String id) async {
    await _dio.patch<Map<String, dynamic>>('/api/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _dio.patch<Map<String, dynamic>>('/api/notifications/read-all');
  }

  AppNotification _fromApi(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        type: _typeFromString(j['type'] as String? ?? 'system'),
        createdAt: DateTime.parse(j['createdAt'] as String),
        isRead: (j['isRead'] as bool?) ?? false,
        entityId: ((j['data'] as Map?)?.cast<String, dynamic>())?['entityId'] as String?,
        targetRoute: ((j['data'] as Map?)?.cast<String, dynamic>())?['targetRoute'] as String?,
      );

  AppNotificationType _typeFromString(String s) {
    return AppNotificationType.values.firstWhere(
      (t) => _wireName(t) == s,
      orElse: () => AppNotificationType.system,
    );
  }

  String _wireName(AppNotificationType t) {
    // Backend uses snake_case; our enum is lowerCamelCase.
    switch (t) {
      case AppNotificationType.accountVerified:
        return 'account_verified';
      case AppNotificationType.kycApproved:
        return 'kyc_approved';
      case AppNotificationType.kycRejected:
        return 'kyc_rejected';
      case AppNotificationType.listingApproved:
        return 'listing_approved';
      case AppNotificationType.listingRejected:
        return 'listing_rejected';
      case AppNotificationType.bookingRequested:
        return 'booking_requested';
      case AppNotificationType.bookingAccepted:
        return 'booking_accepted';
      case AppNotificationType.bookingRejected:
        return 'booking_rejected';
      case AppNotificationType.paymentSuccess:
        return 'payment_success';
      case AppNotificationType.paymentFailed:
        return 'payment_failed';
      case AppNotificationType.orderStarted:
        return 'order_started';
      case AppNotificationType.orderCompleted:
        return 'order_completed';
      case AppNotificationType.messageReceived:
        return 'message_received';
      case AppNotificationType.reviewReceived:
        return 'review_received';
      case AppNotificationType.refundProcessed:
        return 'refund_processed';
      case AppNotificationType.disputeUpdated:
        return 'dispute_updated';
      case AppNotificationType.payoutProcessed:
        return 'payout_processed';
      case AppNotificationType.system:
        return 'system';
    }
  }
}
