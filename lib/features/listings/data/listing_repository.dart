import '../../../shared/models/listing.dart';
import '../../../shared/models/review.dart';

/// Search criteria mirrored between the search screen and the API layer.
class ListingSearchQuery {
  const ListingSearchQuery({
    this.keyword,
    this.categoryId,
    this.listingType,
    this.minPrice,
    this.maxPrice,
    this.city,
    this.sort = 'relevance',
    this.page = 1,
    this.pageSize = 20,
  });

  final String? keyword;
  final String? categoryId;
  final ListingType? listingType;
  final double? minPrice;
  final double? maxPrice;
  final String? city;
  final String sort;
  final int page;
  final int pageSize;
}

/// Draft used when creating a listing. Uses primitives so callers don't
/// have to construct a fully-formed [Listing] object.
class ListingDraft {
  const ListingDraft({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.listingType,
    required this.price,
    required this.priceUnit,
    required this.currency,
    required this.quantity,
    required this.city,
    required this.country,
    this.securityDeposit = 0,
    this.customAttributes = const {},
    this.images = const [],
    this.deliveryOptions = const ['pickup'],
    this.subcategoryId,
    this.state,
    this.address,
    this.postalCode,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String description;
  final String categoryId;
  final String? subcategoryId;
  final ListingType listingType;
  final double price;
  final PriceUnit priceUnit;
  final double securityDeposit;
  final String currency;
  final int quantity;
  final Map<String, dynamic> customAttributes;
  final List<String> images;
  final List<String> deliveryOptions;

  final String city;
  final String country;
  final String? state;
  final String? address;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
}

/// Data source for listings: search, detail, create, favorites, and reviews.
abstract class ListingRepository {
  Future<List<Listing>> search(ListingSearchQuery query);

  Future<Listing> byId(String id);

  Future<Listing> create(ListingDraft draft);

  /// Toggle whether the current user has this listing favorited. Returns the
  /// new state (`true` = now favorited).
  Future<bool> toggleFavorite(String productId);

  Future<List<Listing>> favorites();

  Future<List<Review>> reviewsFor(String productId);

  /// Similar/recommended items — used on the listing detail screen.
  /// Backed by "same category, newest first" for MVP.
  Future<List<Listing>> similar(String productId);
}
