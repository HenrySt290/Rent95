import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../auth/presentation/auth_controller.dart';
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

/// Favorites state kept locally as a Set<String> for O(1) lookups.
///
/// Audit M1: hydration now runs whenever the authenticated user id
/// changes, not just once on construction. This guarantees favorites
/// load even when the auth bootstrap finishes AFTER this controller
/// is first created (which is the normal cold-start ordering).
///
/// Audit M4: exposes an [errors$] stream so the UI can surface toggle
/// failures instead of silently rolling back.
final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsController, Set<String>>((ref) {
  final controller = FavoriteIdsController(ref.watch(listingRepositoryProvider));

  // React to login / logout / account switch.
  ref.listen<String?>(
    authControllerProvider.select((s) => s.initialized ? s.user?.id : null),
    (previous, next) {
      // `next == null` covers both "not yet initialised" and "logged out".
      // We can't distinguish those without reading initialized separately,
      // so on null we clear and on non-null we hydrate. A brief empty
      // window during bootstrap is fine.
      if (next == null) {
        controller.clearLocal();
      } else if (previous != next) {
        controller.hydrate();
      }
    },
    fireImmediately: true,
  );

  ref.onDispose(controller.disposeStreams);
  return controller;
});

/// Emits a user-facing error whenever a favorite toggle fails against the
/// server. Screens subscribe via `ref.listen` and pop a SnackBar.
final favoriteErrorsProvider = StreamProvider<String>((ref) {
  final controller = ref.watch(favoriteIdsProvider.notifier);
  return controller.errors$;
});

class FavoriteIdsController extends StateNotifier<Set<String>> {
  FavoriteIdsController(this._repo) : super(const <String>{});
  final ListingRepository _repo;

  final StreamController<String> _errors = StreamController<String>.broadcast();
  Stream<String> get errors$ => _errors.stream;

  Future<void> hydrate() async {
    try {
      final favs = await _repo.favorites();
      state = favs.map((f) => f.id).toSet();
    } catch (_) {
      // Non-critical: keep whatever optimistic state we already had. The
      // toggle path re-tries against the server on every user tap anyway.
    }
  }

  void clearLocal() {
    if (state.isNotEmpty) state = const <String>{};
  }

  /// Optimistically flip the local set, then reconcile with the server.
  /// The synchronous state mutation guarantees the heart icon re-renders
  /// in the same frame (< 16ms).
  Future<void> toggle(String id) async {
    final wasFav = state.contains(id);
    final next = Set<String>.from(state);
    if (wasFav) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;

    try {
      final nowFav = await _repo.toggleFavorite(id);
      // Reconcile with server truth in case the optimistic guess was wrong
      // (e.g. the item was already un-favored on another device).
      final reconciled = Set<String>.from(state);
      if (nowFav) {
        reconciled.add(id);
      } else {
        reconciled.remove(id);
      }
      state = reconciled;
    } catch (_) {
      // Roll back optimistically-changed state and surface a user-visible
      // error (audit M4) instead of failing silently.
      final rollback = Set<String>.from(state);
      if (wasFav) {
        rollback.add(id);
      } else {
        rollback.remove(id);
      }
      state = rollback;
      if (!_errors.isClosed) {
        _errors.add("Couldn't save that just now. Check your connection and try again.");
      }
    }
  }

  bool isFav(String id) => state.contains(id);

  void disposeStreams() {
    if (!_errors.isClosed) _errors.close();
  }
}
