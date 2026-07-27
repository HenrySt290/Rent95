import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/services/mock_store.dart';
import 'api_notification_repository.dart';
import 'mock_notification_repository.dart';
import 'notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return chooseRepo<NotificationRepository>(
    ref,
    mock: () => MockNotificationRepository(ref.watch(mockStoreProvider)),
    real: () => ApiNotificationRepository(ref.watch(apiClientProvider)),
  );
});
