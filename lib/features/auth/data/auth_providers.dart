import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/services/mock_store.dart';
import '../data/api_auth_repository.dart';
import '../data/auth_repository.dart';
import '../data/mock_auth_repository.dart';

/// The single Riverpod entry-point for choosing between the real and mock
/// [AuthRepository]. Every other file in the auth feature depends on this,
/// so flipping `USE_MOCKS` toggles everything at once.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return chooseRepo<AuthRepository>(
    ref,
    mock: () => MockAuthRepository(
      store: ref.watch(mockStoreProvider),
      storage: ref.watch(tokenStorageProvider),
    ),
    real: () => ApiAuthRepository(
      dio: ref.watch(apiClientProvider),
      storage: ref.watch(tokenStorageProvider),
    ),
  );
});
