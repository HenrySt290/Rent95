import 'dart:async';

import 'package:dio/dio.dart';

import '../../constants/env.dart';
import '../../storage/token_storage.dart';
import '../auth_event_bus.dart';

/// Handles the "access token expired → refresh → retry the original request"
/// dance, safely under concurrency.
///
/// ### Correctness guarantees
///
/// - **Single-flight refresh.** If 20 requests fire in parallel and all get
///   401, only *one* `POST /api/auth/refresh-token` is made. The other 19
///   await a shared [Completer] and then retry with the new token.
///
/// - **Never recursive.** The refresh call itself uses a *separate* Dio
///   instance (`_refreshDio`) that has zero interceptors, so a 401 on refresh
///   cannot loop through this interceptor again.
///
/// - **Never retries a POST/PATCH/PUT that was already retried.** We tag the
///   request via `extra[_retryFlag]` to avoid infinite retries if the server
///   keeps returning 401.
///
/// - **Force-logout on refresh failure.** If the refresh token is itself
///   invalid or expired, we clear storage and emit [AuthEvent.forceLogout]
///   over [AuthEventBus] so the auth controller can drop session state and
///   the router can bounce the user to /login.
///
/// - **Skip refresh for auth endpoints.** Login/register/refresh are marked
///   with `extra[AuthInterceptor.skipAuth] == true` upstream and are also
///   detected by path so they never trigger a refresh loop.
class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor({
    required TokenStorage storage,
    required AuthEventBus events,
    required String baseUrl,
    Dio? refreshDio,
  })  : _storage = storage,
        _events = events,
        _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: const {'Accept': 'application/json'},
              ),
            );

  final TokenStorage _storage;
  final AuthEventBus _events;

  /// A bare Dio with NO interceptors. Used exclusively for the refresh call,
  /// so we can't accidentally recurse back into this interceptor.
  final Dio _refreshDio;

  Completer<String?>? _refreshCompleter;

  /// Marks a RequestOptions object as having already been retried, so we
  /// don't loop forever if the new token is somehow also rejected.
  static const _retryFlag = '__rent95_retried__';

  /// Set this to `true` on any request that should NOT trigger a refresh
  /// (e.g. the login/register endpoints themselves).
  ///
  ///   `dio.post('/api/auth/login', options: Options(extra: {TokenRefreshInterceptor.skipRefresh: true}))`
  static const String skipRefresh = 'skipRefresh';

  static const _refreshEndpoints = <String>{
    '/api/auth/refresh-token',
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/logout',
  };

  bool _isAuthEndpoint(RequestOptions options) {
    if (options.extra[skipRefresh] == true) return true;
    return _refreshEndpoints.any((p) => options.path.contains(p));
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final req = err.requestOptions;

    // Only try to recover from 401s that came from an authenticated call.
    if (response?.statusCode != 401 || _isAuthEndpoint(req) || req.extra[_retryFlag] == true) {
      return handler.next(err);
    }

    try {
      final newAccessToken = await _refreshTokenSingleFlight();
      if (newAccessToken == null) {
        // Refresh failed — session is dead. The bus already fired forceLogout.
        return handler.next(err);
      }

      // Retry the original request with the new token.
      final retried = await _retry(req, newAccessToken);
      return handler.resolve(retried);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (e) {
      return handler.next(err);
    }
  }

  /// Coalesces concurrent refresh attempts into a single HTTP call.
  Future<String?> _refreshTokenSingleFlight() {
    final inflight = _refreshCompleter;
    if (inflight != null && !inflight.isCompleted) {
      return inflight.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    _performRefresh().then((token) {
      if (!completer.isCompleted) completer.complete(token);
    }).catchError((Object err, StackTrace st) {
      if (!completer.isCompleted) completer.complete(null);
    }).whenComplete(() {
      // Clear the slot so the *next* 401 (which will now happen much later,
      // after the fresh access token has expired) can trigger a new refresh.
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    });

    return completer.future;
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _forceLogout();
      return null;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      final body = response.data;
      // Support both envelope shapes: {success, data:{accessToken,...}} or flat.
      final payload = (body?['data'] as Map?)?.cast<String, dynamic>() ??
          (body ?? const <String, dynamic>{});
      final newAccess = payload['accessToken'] as String?;
      final newRefresh = payload['refreshToken'] as String?;

      if (newAccess == null || newAccess.isEmpty) {
        await _forceLogout();
        return null;
      }

      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh, // if the server rotates it, save it
      );
      return newAccess;
    } on DioException catch (e) {
      // 401/403 on the refresh endpoint means the refresh token itself is dead.
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        await _forceLogout();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions original, String newAccessToken) {
    final headers = Map<String, dynamic>.from(original.headers)
      ..['Authorization'] = 'Bearer $newAccessToken';
    final newExtra = Map<String, dynamic>.from(original.extra)..[_retryFlag] = true;

    // We retry via the refresh Dio (which has no interceptors of its own) so
    // we don't recurse back into any request-side interceptor that might have
    // stale state — but we still get response mapping because we resolve the
    // outer handler with this Response.
    return _refreshDio.fetch<dynamic>(
      RequestOptions(
        path: original.path,
        method: original.method,
        baseUrl: original.baseUrl,
        headers: headers,
        data: original.data,
        queryParameters: original.queryParameters,
        extra: newExtra,
        responseType: original.responseType,
        contentType: original.contentType,
        followRedirects: original.followRedirects,
        maxRedirects: original.maxRedirects,
        listFormat: original.listFormat,
        receiveDataWhenStatusError: original.receiveDataWhenStatusError,
        connectTimeout: original.connectTimeout,
        receiveTimeout: original.receiveTimeout,
        sendTimeout: original.sendTimeout,
        cancelToken: original.cancelToken,
        validateStatus: original.validateStatus,
      ),
    );
  }

  Future<void> _forceLogout() async {
    await _storage.clear();
    _events.emit(AuthEvent.forceLogout);
    if (Env.isDev) {
      // ignore: avoid_print
      print('[Rent95] Refresh token invalid — forced logout.');
    }
  }
}
