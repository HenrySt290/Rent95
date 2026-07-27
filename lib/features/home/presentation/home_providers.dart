import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../categories/data/category_providers.dart';
import '../../listings/data/listing_repository.dart';
import '../../listings/data/listing_providers.dart';

/// Re-export the shared categories provider under its old name so existing
/// screens (`home_screen.dart`, `search_screen.dart`) keep working.
final categoriesProvider = categoriesFutureProvider;

/// Featured = top-rated listings, capped at 6. Uses the shared search
/// endpoint so the mock and real repos both go through the same code path.
final featuredListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final repo = ref.watch(listingRepositoryProvider);
  final list = await repo.search(
    const ListingSearchQuery(sort: 'rating', pageSize: 6),
  );
  return list;
});

final nearbyListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final repo = ref.watch(listingRepositoryProvider);
  // TODO(location): pass the user's current city/coords once we wire up geolocator.
  return repo.search(const ListingSearchQuery(sort: 'newest', pageSize: 20));
});

/// Favorites state kept locally as a Set<String> for O(1) lookups in the UI.
/// The repository is the source of truth on init and on toggle.
final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsController, Set<String>>((ref) {
  return FavoriteIdsController(ref.watch(listingRepositoryProvider));
});

class FavoriteIdsController extends StateNotifier<Set<String>> {
  FavoriteIdsController(this._repo) : super(const <String>{}) {
    _hydrate();
  }
  final ListingRepository _repo;

  Future<void> _hydrate() async {
    try {
      final favs = await _repo.favorites();
      state = favs.map((f) => f.id).toSet();
    } catch (_) {
      // Not authenticated yet, or offline — start empty. The favourite
      // buttons will still work optimistically once the user taps.
    }
  }

  Future<void> toggle(String id) async {
    // Optimistic update, then reconcile with the server.
    final wasFav = state.contains(id);
    final next = Set<String>.from(state);
    wasFav ? next.remove(id) : next.add(id);
    state = next;
    try {
      final nowFav = await _repo.toggleFavorite(id);
      final reconciled = Set<String>.from(state);
      nowFav ? reconciled.add(id) : reconciled.remove(id);
      state = reconciled;
    } catch (_) {
      // Rollback on failure — must create a *new* Set so Riverpod notifies.
      final rollback = Set<String>.from(state);
      if (wasFav) {
        rollback.add(id);
      } else {
        rollback.remove(id);
      }
      state = rollback;
    }
  }

  bool isFav(String id) => state.contains(id);
}
