import '../../../shared/models/review.dart';
import '../../../shared/services/mock_store.dart';
import 'review_repository.dart';

class MockReviewRepository implements ReviewRepository {
  MockReviewRepository(this._store);
  final MockStore _store;

  @override
  Future<Review> submit(ReviewDraft d) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    // Look up the order to figure out which product this review is for.
    final order = _store.orders.where((o) => o.id == d.orderId).firstOrNull;
    final review = Review(
      id: 'rev_${DateTime.now().microsecondsSinceEpoch}',
      orderId: d.orderId,
      productId: order?.productId ?? 'unknown',
      reviewerId: _store.currentUser.id,
      reviewerName: _store.currentUser.fullName,
      revieweeId: order?.sellerId ?? 'unknown',
      rating: d.rating,
      comment: d.comment,
      createdAt: DateTime.now(),
    );
    _store.reviews.insert(0, review);
    return review;
  }

  @override
  Future<List<Review>> forProduct(String productId) async {
    return _store.reviews.where((r) => r.productId == productId).toList();
  }
}
