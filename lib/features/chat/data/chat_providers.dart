import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/repo_picker.dart';
import '../../../shared/services/mock_store.dart';
import '../../auth/presentation/auth_controller.dart';
import 'api_chat_repository.dart';
import 'chat_repository.dart';
import 'mock_chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return chooseRepo<ChatRepository>(
    ref,
    mock: () => MockChatRepository(ref.watch(mockStoreProvider)),
    real: () {
      // Need the current user's id to figure out who "the other person" is
      // in each conversation. Watch the whole auth state so the repo swaps
      // if the user logs in as someone else.
      final userId = ref.watch(authControllerProvider).user?.id ?? '';
      return ApiChatRepository(ref.watch(apiClientProvider), userId);
    },
  );
});
