import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import 'api_upload_repository.dart';
import 'mock_upload_repository.dart';
import 'upload_repository.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return chooseRepo<UploadRepository>(
    ref,
    mock: () => MockUploadRepository(),
    real: () => ApiUploadRepository(apiDio: ref.watch(apiClientProvider)),
  );
});
