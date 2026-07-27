import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/models/review.dart';
import '../../../shared/services/mock_store.dart';

final listingByIdProvider =
    FutureProvider.autoDispose.family<Listing?, String>((ref, id) async {
  final store = ref.read(mockStoreProvider);
  await Future<void>.delayed(const Duration(milliseconds: 200));
  final match = store.listings.where((l) => l.id == id);
  return match.isEmpty ? null : match.first;
});

final reviewsForProductProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, productId) async {
  final store = ref.read(mockStoreProvider);
  return store.reviews.where((r) => r.productId == productId).toList();
});

final similarListingsProvider =
    FutureProvider.autoDispose.family<List<Listing>, String>((ref, id) async {
  final store = ref.read(mockStoreProvider);
  final base = store.listings.where((l) => l.id == id).firstOrNull;
  if (base == null) return [];
  return store.listings
      .where((l) => l.id != id && l.categoryId == base.categoryId)
      .take(4)
      .toList();
});
