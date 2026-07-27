import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/services/mock_store.dart';
import 'api_review_repository.dart';
import 'mock_review_repository.dart';
import 'review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return chooseRepo<ReviewRepository>(
    ref,
    mock: () => MockReviewRepository(ref.watch(mockStoreProvider)),
    real: () => ApiReviewRepository(ref.watch(apiClientProvider)),
  );
});
