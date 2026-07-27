import 'package:flutter/foundation.dart';

@immutable
class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.rating,
    required this.createdAt,
    this.reviewerAvatarUrl,
    this.comment,
    this.sellerResponse,
  });

  final String id;
  final String orderId;
  final String productId;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final String revieweeId;
  final int rating;
  final String? comment;
  final String? sellerResponse;
  final DateTime createdAt;
}
