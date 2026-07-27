import '../../../shared/models/category.dart';

/// Data source for marketplace categories.
///
/// Categories are effectively static (admin-managed) but change occasionally,
/// so we don't cache them for the whole app lifetime — a per-provider fetch
/// with Riverpod's built-in caching is fine.
abstract class CategoryRepository {
  Future<List<Category>> list();

  /// The full parent→children tree. Only the first level is populated in v1.
  Future<List<Category>> tree();
}
