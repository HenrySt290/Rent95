import '../../../shared/models/user.dart';

/// Contract for the auth data source. One method per API endpoint we hit.
///
/// Repositories are the *only* place that knows whether we're talking to
/// a mock, a real backend, or something else entirely. Controllers depend on
/// this abstraction so tests can stub it and so `USE_MOCKS=true/false` is a
/// one-line toggle in `auth_providers.dart`.
abstract class AuthRepository {
  /// Called on app start. Returns the current user if a saved session is
  /// still valid, or `null` if not authenticated / tokens are dead.
  Future<AppUser?> currentUser();

  /// Email + password login. On success, tokens must be persisted before
  /// this method returns.
  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  });

  /// Google OAuth login. Implementations may open the Google Sign-In UI
  /// themselves.
  Future<AppUser> loginWithGoogle();

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  });

  /// Revoke the refresh token server-side and clear local storage. Safe to
  /// call even if we're not really logged in.
  Future<void> logout();
}
