import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import 'api_payment_repository.dart';
import 'mock_payment_repository.dart';
import 'payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return chooseRepo<PaymentRepository>(
    ref,
    mock: () => MockPaymentRepository(),
    real: () => ApiPaymentRepository(ref.watch(apiClientProvider)),
  );
});
