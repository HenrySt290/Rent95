import '../../../shared/models/review.dart';

class ReviewDraft {
  const ReviewDraft({
    required this.orderId,
    required this.rating,
    this.comment,
    this.mediaUrls = const [],
  });
  final String orderId;
  final int rating;
  final String? comment;
  final List<String> mediaUrls;
}

abstract class ReviewRepository {
  Future<Review> submit(ReviewDraft draft);

  Future<List<Review>> forProduct(String productId);
}
