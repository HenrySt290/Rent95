import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/services/mock_store.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final store = ref.read(mockStoreProvider);
  return List.unmodifiable(store.categories);
});

final featuredListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final store = ref.read(mockStoreProvider);
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final l = List<Listing>.from(store.listings);
  l.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
  return l.take(6).toList();
});

final nearbyListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final store = ref.read(mockStoreProvider);
  await Future<void>.delayed(const Duration(milliseconds: 250));
  return List.unmodifiable(store.listings);
});

final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsController, Set<String>>((ref) {
  return FavoriteIdsController(ref.read(mockStoreProvider));
});

class FavoriteIdsController extends StateNotifier<Set<String>> {
  FavoriteIdsController(this._store) : super(Set<String>.from(_store.favorites));
  final MockStore _store;

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    _store.favorites
      ..clear()
      ..addAll(next);
  }

  bool isFav(String id) => state.contains(id);
}
