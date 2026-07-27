import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/services/mock_store.dart';
import 'api_listing_repository.dart';
import 'listing_repository.dart';
import 'mock_listing_repository.dart';

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return chooseRepo<ListingRepository>(
    ref,
    mock: () => MockListingRepository(ref.watch(mockStoreProvider)),
    real: () => ApiListingRepository(ref.watch(apiClientProvider)),
  );
});
