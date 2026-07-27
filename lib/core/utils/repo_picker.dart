import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/env.dart';

/// A tiny helper that returns the mock impl when [Env.useMocks] is `true` and
/// the real (API-backed) impl otherwise. Keeps the ternary out of every
/// feature file.
///
/// ```dart
/// final listingRepositoryProvider = Provider<ListingRepository>((ref) {
///   return chooseRepo(
///     ref,
///     mock: () => MockListingRepository(ref.watch(mockStoreProvider)),
///     real: () => ApiListingRepository(ref.watch(apiClientProvider)),
///   );
/// });
/// ```
T chooseRepo<T>(Ref ref, {
  required T Function() mock,
  required T Function() real,
}) {
  return Env.useMocks ? mock() : real();
}
