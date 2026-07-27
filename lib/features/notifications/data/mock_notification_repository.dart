import '../../../shared/models/notification.dart';
import '../../../shared/services/mock_store.dart';
import 'notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._store);
  final MockStore _store;

  @override
  Future<List<AppNotification>> list() async {
    return List.unmodifiable(_store.notifications);
  }

  @override
  Future<void> markRead(String id) async {
    // no-op — mock notifications don't track read state per-record.
  }

  @override
  Future<void> markAllRead() async {}
}
