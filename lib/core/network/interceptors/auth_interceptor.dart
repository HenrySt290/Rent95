import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';

/// Attaches `Authorization: Bearer <accessToken>` to every outgoing request
/// unless the request opts out via `Options(extra: {skipAuth: true})`.
///
/// This interceptor is intentionally *only* about attaching the header. The
/// [TokenRefreshInterceptor] handles 401 responses and rotation.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);
  final TokenStorage _storage;

  /// Set this on a request to skip attaching the auth header.
  ///   `dio.get(url, options: Options(extra: {AuthInterceptor.skipAuth: true}))`
  static const String skipAuth = 'skipAuth';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuth] == true) {
      return handler.next(options);
    }
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
