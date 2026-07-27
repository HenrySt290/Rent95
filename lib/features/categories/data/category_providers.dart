import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/models/category.dart';
import '../../../shared/services/mock_store.dart';
import 'api_category_repository.dart';
import 'category_repository.dart';
import 'mock_category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return chooseRepo<CategoryRepository>(
    ref,
    mock: () => MockCategoryRepository(ref.watch(mockStoreProvider)),
    real: () => ApiCategoryRepository(ref.watch(apiClientProvider)),
  );
});

/// Cached across widgets. Refresh with `ref.invalidate(categoriesFutureProvider)`
/// if you build an admin flow that mutates them at runtime.
final categoriesFutureProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).list();
});
