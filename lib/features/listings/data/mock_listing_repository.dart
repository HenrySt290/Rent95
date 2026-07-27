import '../../../shared/models/listing.dart';
import '../../../shared/models/review.dart';
import '../../../shared/services/mock_store.dart';
import 'listing_repository.dart';

class MockListingRepository implements ListingRepository {
  MockListingRepository(this._store);
  final MockStore _store;

  @override
  Future<List<Listing>> search(ListingSearchQuery q) {
    return _store.searchListings(
      keyword: q.keyword,
      categoryId: q.categoryId,
      minPrice: q.minPrice,
      maxPrice: q.maxPrice,
      city: q.city,
      listingType: q.listingType,
      sort: q.sort,
    );
  }

  @override
  Future<Listing> byId(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final match = _store.listings.where((l) => l.id == id);
    if (match.isEmpty) throw StateError('Listing not found');
    return match.first;
  }

  @override
  Future<Listing> create(ListingDraft d) {
    final draft = Listing(
      id: 'temp',
      ownerId: _store.currentUser.id,
      ownerName: _store.currentUser.fullName,
      title: d.title,
      description: d.description,
      categoryId: d.categoryId,
      subcategoryId: d.subcategoryId,
      listingType: d.listingType,
      price: d.price,
      priceUnit: d.priceUnit,
      securityDeposit: d.securityDeposit,
      currency: d.currency,
      quantity: d.quantity,
      images: d.images,
      customAttributes: d.customAttributes,
      deliveryOptions: d.deliveryOptions,
      location: ListingLocation(city: d.city, country: d.country, state: d.state),
    );
    return _store.createListing(draft);
  }

  @override
  Future<bool> toggleFavorite(String productId) async {
    if (_store.favorites.contains(productId)) {
      _store.favorites.remove(productId);
      return false;
    }
    _store.favorites.add(productId);
    return true;
  }

  @override
  Future<List<Listing>> favorites() async {
    return _store.listings.where((l) => _store.favorites.contains(l.id)).toList();
  }

  @override
  Future<List<Review>> reviewsFor(String productId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _store.reviews.where((r) => r.productId == productId).toList();
  }

  @override
  Future<List<Listing>> similar(String productId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final base = _store.listings.where((l) => l.id == productId).firstOrNull;
    if (base == null) return const [];
    return _store.listings
        .where((l) => l.id != productId && l.categoryId == base.categoryId)
        .take(4)
        .toList();
  }
}
