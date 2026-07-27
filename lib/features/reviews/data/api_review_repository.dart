import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../shared/models/review.dart';
import 'review_repository.dart';

class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._dio);
  final Dio _dio;

  @override
  Future<Review> submit(ReviewDraft d) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/reviews',
      data: <String, dynamic>{
        'orderId': d.orderId,
        'rating': d.rating,
        if (d.comment != null && d.comment!.isNotEmpty) 'comment': d.comment,
        if (d.mediaUrls.isNotEmpty) 'mediaUrls': d.mediaUrls,
      },
    );
    return decodeObject(res, _fromApi);
  }

  @override
  Future<List<Review>> forProduct(String productId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/products/$productId/reviews');
    return decodeList(res, _fromApi);
  }

  Review _fromApi(Map<String, dynamic> j) {
    final reviewer = (j['reviewer'] as Map?)?.cast<String, dynamic>();
    return Review(
      id: j['id'] as String,
      orderId: j['orderId'] as String,
      productId: j['productId'] as String,
      reviewerId: j['reviewerId'] as String,
      reviewerName: (reviewer?['fullName'] as String?) ?? 'Anonymous',
      reviewerAvatarUrl: reviewer?['profileImageUrl'] as String?,
      revieweeId: j['revieweeId'] as String,
      rating: (j['rating'] as num).toInt(),
      comment: j['comment'] as String?,
      sellerResponse: j['sellerResponse'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}
