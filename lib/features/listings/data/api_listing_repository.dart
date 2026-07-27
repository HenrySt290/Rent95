import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_mappers.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/review.dart';
import 'listing_repository.dart';

class ApiListingRepository implements ListingRepository {
  ApiListingRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Listing>> search(ListingSearchQuery q) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/products',
      queryParameters: <String, dynamic>{
        if (q.keyword != null && q.keyword!.isNotEmpty) 'keyword': q.keyword,
        if (q.categoryId != null) 'categoryId': q.categoryId,
        if (q.listingType != null) 'listingType': q.listingType!.name,
        if (q.minPrice != null) 'minPrice': q.minPrice,
        if (q.maxPrice != null) 'maxPrice': q.maxPrice,
        if (q.city != null && q.city!.isNotEmpty) 'city': q.city,
        'sort': q.sort,
        'page': q.page,
        'pageSize': q.pageSize,
      },
    );
    return listingsFromEnvelope(res);
  }

  @override
  Future<Listing> byId(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/products/$id');
    return decodeObject(res, listingFromApi);
  }

  @override
  Future<Listing> create(ListingDraft d) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/products',
      data: <String, dynamic>{
        'title': d.title,
        'description': d.description,
        'categoryId': d.categoryId,
        if (d.subcategoryId != null) 'subcategoryId': d.subcategoryId,
        'listingType': d.listingType.name,
        'price': d.price,
        'priceUnit': d.priceUnit.name,
        'securityDeposit': d.securityDeposit,
        'currency': d.currency,
        'quantity': d.quantity,
        'customAttributes': d.customAttributes,
        'deliveryOptions': d.deliveryOptions,
        if (d.images.isNotEmpty) 'images': d.images,
        'location': <String, dynamic>{
          'address': d.address ?? '${d.city}, ${d.country}',
          'city': d.city,
          if (d.state != null) 'state': d.state,
          'country': d.country,
          if (d.postalCode != null) 'postalCode': d.postalCode,
          // Server currently requires lat/long; default to a rough centroid
          // when the client didn't collect one. Fine for MVP.
          'latitude': d.latitude ?? 0,
          'longitude': d.longitude ?? 0,
        },
      },
    );
    return decodeObject(res, listingFromApi);
  }

  @override
  Future<bool> toggleFavorite(String productId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/products/$productId/favorite',
    );
    final data = decodeObject(res, (m) => m);
    return (data['favorited'] as bool?) ?? false;
  }

  @override
  Future<List<Listing>> favorites() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/products/me/favorites');
    // The favorite records nest the product under `product`.
    final body = res.data;
    final raw = body is Map ? body['data'] : body;
    if (raw is! List) return const [];
    return raw
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          final product = (m['product'] as Map).cast<String, dynamic>();
          return listingFromApi(product);
        })
        .toList(growable: false);
  }

  @override
  Future<List<Review>> reviewsFor(String productId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/products/$productId/reviews');
    return decodeList(res, _reviewFromApi);
  }

  @override
  Future<List<Listing>> similar(String productId) async {
    // Backend doesn't expose /similar directly in MVP — we approximate by
    // pulling the product, then searching the same category.
    final base = await byId(productId);
    final list = await search(
      ListingSearchQuery(categoryId: base.categoryId, sort: 'newest', pageSize: 8),
    );
    return list.where((l) => l.id != productId).take(4).toList(growable: false);
  }

  Review _reviewFromApi(Map<String, dynamic> j) {
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
