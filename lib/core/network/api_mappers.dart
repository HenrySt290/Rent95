import 'package:dio/dio.dart';

import '../../shared/models/listing.dart';
import 'safe_json.dart';

/// API-shape mappers.
///
/// The backend returns Prisma-serialized shapes that don't exactly match the
/// mobile app's plain-Dart models (e.g. `media[]` of `ProductMedia` records
/// vs. `images: string[]` on the client). These free functions do that
/// translation in one place so it stays consistent across every repository.
///
/// They live in `core/network/` (not the shared models) because they're
/// coupled to the wire format, not the domain shape.
///
/// **Safety contract (see `safe_json.dart` for the primitives):**
///
/// 1. Every field access goes through a type-safe coercer that returns a
///    default on shape mismatch instead of throwing. A hostile CDN cannot
///    freeze the UI by shipping a `bool` where we expect a `String`.
///
/// 2. Numeric fields (price, deposit, rating) are clamped to `[min, max]`
///    at the mapper. A negative price cannot enter our domain model.
///
/// 3. List-of-listings is mapped with `mapListSafely`: a single corrupted
///    record is dropped and logged, the rest of the page still renders.
///
/// 4. Enum-shaped strings fall back to a safe default. An unknown
///    `listingType` becomes `rent`, not a crash.

/// Convert a Prisma-serialized `Product` (with its `media`, `location`,
/// `owner`, `category` relations) into the app's [Listing] model.
///
/// Never throws. If the input is so corrupted that even ID and title are
/// missing, returns a placeholder [Listing] with `status = removed` so the
/// UI can skip it during render. Callers should still prefer
/// [mapListSafely] to drop these entirely.
Listing listingFromApi(Map<String, dynamic> j) {
  final owner = asMapOrNull(j['owner']);
  final location = asMapOrNull(j['location']);

  return Listing(
    // ID is the one field we can't sanely default — an empty ID would
    // break every downstream reference. Skip via mapListSafely instead.
    id: asString(j['id']),
    ownerId: asString(j['ownerId']),
    ownerName: asStringOrNull(owner?['fullName']) ??
        asStringOrNull(j['ownerName']) ??
        '',
    ownerAvatarUrl: asStringOrNull(owner?['profileImageUrl']),
    title: asString(j['title'], fallback: '(untitled)'),
    description: asString(j['description']),
    categoryId: asString(j['categoryId']),
    subcategoryId: asStringOrNull(j['subcategoryId']),
    listingType: listingTypeFromString(asString(j['listingType'], fallback: 'rent')),
    // Prices are clamped to non-negative and a sane ceiling.
    // A compromised feed sending `-500` or `1e30` cannot poison the model.
    price: asDouble(j['price'], minValue: 0, maxValue: 1e9),
    priceUnit: priceUnitFromString(asString(j['priceUnit'], fallback: 'day')),
    securityDeposit: asDouble(j['securityDeposit'], minValue: 0, maxValue: 1e9),
    currency: asString(j['currency'], fallback: 'USD'),
    quantity: asInt(j['quantity'], fallback: 1, minValue: 0, maxValue: 100000),
    // Media list capped so a compromised feed can't inject a million URLs.
    images: mapListSafely<String>(
      j['media'],
      (m) {
        final url = asStringOrNull(m['url']);
        if (url == null) throw const FormatException('missing url');
        return url;
      },
      maxLength: 24,
      context: 'listing.media',
    ),
    location: ListingLocation(
      city: asString(location?['city']),
      country: asString(location?['country']),
      state: asStringOrNull(location?['state']),
      address: asStringOrNull(location?['address']),
      postalCode: asStringOrNull(location?['postalCode']),
      latitude: _latOrNull(location?['latitude']),
      longitude: _lonOrNull(location?['longitude']),
    ),
    customAttributes: asMap(j['customAttributes']),
    status: listingStatusFromString(asString(j['status'], fallback: 'active')),
    ratingAverage: asDouble(j['ratingAverage'], minValue: 0, maxValue: 5),
    reviewCount: asInt(j['reviewCount'], minValue: 0),
    viewCount: asInt(j['viewCount'], minValue: 0),
    favoriteCount: asInt(j['favoriteCount'], minValue: 0),
    deliveryOptions: () {
      final opts = asStringList(j['deliveryOptions'], maxLength: 8);
      return opts.isEmpty ? const <String>['pickup'] : opts;
    }(),
  );
}

double? _latOrNull(Object? v) {
  if (v == null) return null;
  final n = asDouble(v, minValue: -90, maxValue: 90, fallback: double.nan);
  return n.isNaN ? null : n;
}

double? _lonOrNull(Object? v) {
  if (v == null) return null;
  final n = asDouble(v, minValue: -180, maxValue: 180, fallback: double.nan);
  return n.isNaN ? null : n;
}

/// Decode a list of listings from a paginated `GET /api/products` response.
///
/// Uses [mapListSafely] so a poisoned element is dropped, not fatal.
/// Also drops any element whose ID resolved to empty (see mapper contract).
List<Listing> listingsFromEnvelope(Response<dynamic> response) {
  final body = response.data;
  final raw = body is Map ? body['data'] : body;
  final all = mapListSafely<Listing>(
    raw,
    listingFromApi,
    maxLength: 200,
    context: 'GET /products',
  );
  // Belt-and-braces: strip any placeholders (empty id) that survived.
  return all.where((l) => l.id.isNotEmpty).toList(growable: false);
}
