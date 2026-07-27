import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/services/mock_store.dart';
import 'api_order_repository.dart';
import 'mock_order_repository.dart';
import 'order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return chooseRepo<OrderRepository>(
    ref,
    mock: () => MockOrderRepository(ref.watch(mockStoreProvider)),
    real: () => ApiOrderRepository(ref.watch(apiClientProvider)),
  );
});
