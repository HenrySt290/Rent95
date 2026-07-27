import '../../../core/storage/token_storage.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/mock_store.dart';
import 'auth_repository.dart';

/// In-memory mock. Backs the app in `USE_MOCKS=true` mode so the whole thing
/// runs without a backend.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({required this.store, required this.storage});
  final MockStore store;
  final TokenStorage storage;

  @override
  Future<AppUser?> currentUser() async {
    final token = await storage.readAccessToken();
    if (token == null || token.isEmpty) return null;
    return store.currentUser;
  }

  @override
  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@') || password.length < 4) {
      throw StateError('Enter a valid email and a password of at least 4 characters.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await storage.saveTokens(
      accessToken: 'mock.access.${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock.refresh',
    );
    return store.currentUser;
  }

  @override
  Future<AppUser> loginWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await storage.saveTokens(
      accessToken: 'mock.google.${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock.refresh',
    );
    return store.currentUser;
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await storage.saveTokens(
      accessToken: 'mock.reg.${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock.refresh',
    );
    return store.currentUser.copyWith(fullName: fullName, isEmailVerified: false);
  }

  @override
  Future<void> logout() async {
    await storage.clear();
  }
}
