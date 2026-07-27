import 'package:dio/dio.dart';

import '../../shared/models/listing.dart';

/// API-shape mappers.
///
/// The backend returns Prisma-serialized shapes that don't exactly match the
/// mobile app's plain-Dart models (e.g. `media[]` of `ProductMedia` records
/// vs. `images: string[]` on the client). These free functions do that
/// translation in one place so it stays consistent across every repository.
///
/// They live in `core/network/` (not the shared models) because they're
/// coupled to the wire format, not the domain shape.

/// Convert a Prisma-serialized `Product` (with its `media`, `location`,
/// `owner`, `category` relations) into the app's [Listing] model.
Listing listingFromApi(Map<String, dynamic> j) {
  final owner = (j['owner'] as Map?)?.cast<String, dynamic>();
  final location = (j['location'] as Map?)?.cast<String, dynamic>();
  final media = (j['media'] as List?) ?? const [];

  return Listing(
    id: j['id'] as String,
    ownerId: j['ownerId'] as String,
    ownerName: (owner?['fullName'] as String?) ?? (j['ownerName'] as String?) ?? '',
    ownerAvatarUrl: owner?['profileImageUrl'] as String?,
    title: j['title'] as String,
    description: (j['description'] as String?) ?? '',
    categoryId: j['categoryId'] as String,
    subcategoryId: j['subcategoryId'] as String?,
    listingType: listingTypeFromString((j['listingType'] as String?) ?? 'rent'),
    price: (j['price'] as num).toDouble(),
    priceUnit: priceUnitFromString((j['priceUnit'] as String?) ?? 'day'),
    securityDeposit: (j['securityDeposit'] as num?)?.toDouble() ?? 0,
    currency: (j['currency'] as String?) ?? 'USD',
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    images: media
        .map((m) => (m as Map).cast<String, dynamic>()['url'] as String)
        .toList(growable: false),
    location: ListingLocation(
      city: (location?['city'] as String?) ?? '',
      country: (location?['country'] as String?) ?? '',
      state: location?['state'] as String?,
      address: location?['address'] as String?,
      postalCode: location?['postalCode'] as String?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
    ),
    customAttributes: ((j['customAttributes'] as Map?)?.cast<String, dynamic>()) ?? const {},
    status: listingStatusFromString((j['status'] as String?) ?? 'active'),
    ratingAverage: (j['ratingAverage'] as num?)?.toDouble() ?? 0,
    reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
    viewCount: (j['viewCount'] as num?)?.toInt() ?? 0,
    favoriteCount: (j['favoriteCount'] as num?)?.toInt() ?? 0,
    deliveryOptions: ((j['deliveryOptions'] as List?) ?? const ['pickup'])
        .map((e) => e.toString())
        .toList(growable: false),
  );
}

/// Decode a list of listings from a paginated `GET /api/products` response.
List<Listing> listingsFromEnvelope(Response<dynamic> response) {
  final body = response.data;
  final raw = body is Map ? body['data'] : body;
  if (raw is! List) return const [];
  return raw
      .map((e) => listingFromApi((e as Map).cast<String, dynamic>()))
      .toList(growable: false);
}
