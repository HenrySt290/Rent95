import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../../shared/models/review.dart';
import '../../listings/data/listing_providers.dart';

final listingByIdProvider =
    FutureProvider.autoDispose.family<Listing?, String>((ref, id) async {
  try {
    return await ref.watch(listingRepositoryProvider).byId(id);
  } catch (_) {
    return null;
  }
});

final reviewsForProductProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, productId) async {
  return ref.watch(listingRepositoryProvider).reviewsFor(productId);
});

final similarListingsProvider =
    FutureProvider.autoDispose.family<List<Listing>, String>((ref, id) async {
  return ref.watch(listingRepositoryProvider).similar(id);
});
