import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/interceptors/auth_interceptor.dart';
import '../../../core/network/interceptors/token_refresh_interceptor.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/user.dart';
import 'auth_repository.dart';

/// Real, API-backed implementation of [AuthRepository].
///
/// Talks to the endpoints defined in `rent95-api`:
///
/// - `POST /api/auth/register`
/// - `POST /api/auth/login`
/// - `POST /api/auth/logout`
/// - `GET  /api/auth/me`
///
/// The login/register endpoints are marked with `skipAuth` and `skipRefresh`
/// so we never send a Bearer header on them and so a 401 doesn't try to
/// refresh (which would be nonsense for "wrong password").
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required Dio dio, required TokenStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final TokenStorage _storage;

  static const _publicOptions = _PublicAuthOptions();

  @override
  Future<AppUser?> currentUser() async {
    final hasSession = await _storage.hasTokens();
    if (!hasSession) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/auth/me');
      return _userFromMe(decodeObject(res, (m) => m));
    } on DioException {
      // If /me fails after a refresh attempt, the network layer will have
      // already forced logout via AuthEventBus. Return null so the auth
      // controller lands in the "not authenticated" state.
      return null;
    }
  }

  @override
  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
      options: _publicOptions.toOptions(),
    );
    return _consumeAuthResponse(res);
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
      options: _publicOptions.toOptions(),
    );
    return _consumeAuthResponse(res);
  }

  @override
  Future<AppUser> loginWithGoogle() async {
    // TODO(auth): implement Google Sign-In flow.
    //
    // Wiring outline (once the app is running on-device and
    // `google_sign_in` is configured for both platforms):
    //
    //   final account = await GoogleSignIn().signIn();
    //   final auth = await account?.authentication;
    //   final idToken = auth?.idToken;
    //   final res = await _dio.post('/api/auth/oauth/google',
    //       data: {'idToken': idToken}, options: _publicOptions.toOptions());
    //   return _consumeAuthResponse(res);
    //
    // Deferred to keep this repository compilable without Google credentials.
    throw UnimplementedError('Google Sign-In is not wired yet on the backend.');
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post<Map<String, dynamic>>(
          '/api/auth/logout',
          data: {'refreshToken': refreshToken},
          options: _publicOptions.toOptions(),
        );
      }
    } catch (_) {
      // Best-effort — we still clear local storage below so the user is
      // "logged out" even if the server call fails (offline, etc).
    } finally {
      await _storage.clear();
    }
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------

  /// Extract user + tokens from a login/register response and persist tokens.
  Future<AppUser> _consumeAuthResponse(Response<Map<String, dynamic>> res) async {
    final data = decodeObject(res, (m) => m);
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw StateError('Auth response missing tokens');
    }
    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    final userJson = (data['user'] as Map?)?.cast<String, dynamic>() ?? data;
    return _userFromMe(userJson);
  }

  AppUser _userFromMe(Map<String, dynamic> j) {
    // /me returns a subset of user fields; register/login return the full user.
    return AppUser(
      id: (j['id'] ?? j['sub']) as String,
      fullName: (j['fullName'] as String?) ?? '',
      email: (j['email'] as String?) ?? '',
      phone: j['phone'] as String?,
      profileImageUrl: j['profileImageUrl'] as String?,
      role: userRoleFromString((j['role'] as String?) ?? 'buyer'),
      isEmailVerified: (j['isEmailVerified'] as bool?) ?? false,
      isPhoneVerified: (j['isPhoneVerified'] as bool?) ?? false,
      ratingAverage: (j['ratingAverage'] as num?)?.toDouble() ?? 0,
      reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Options bag for the "call the auth endpoints without auth headers or
/// automatic refresh" recipe. Extracted so all three methods stay consistent.
class _PublicAuthOptions {
  const _PublicAuthOptions();
  Options toOptions() => Options(extra: const {
        AuthInterceptor.skipAuth: true,
        TokenRefreshInterceptor.skipRefresh: true,
      });
}
