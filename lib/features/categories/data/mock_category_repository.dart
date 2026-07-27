import '../../../shared/models/category.dart';
import '../../../shared/services/mock_store.dart';
import 'category_repository.dart';

class MockCategoryRepository implements CategoryRepository {
  MockCategoryRepository(this._store);
  final MockStore _store;

  @override
  Future<List<Category>> list() async => List.unmodifiable(_store.categories);

  @override
  Future<List<Category>> tree() async => List.unmodifiable(_store.categories);
}
