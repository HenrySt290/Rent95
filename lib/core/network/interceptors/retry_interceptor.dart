import 'dart:math';

import 'package:dio/dio.dart';

/// Retries transient failures with exponential backoff + jitter.
///
/// ### Policy
///
/// - Only retries idempotent HTTP methods: **GET, HEAD, OPTIONS**. Never
///   POST/PATCH/PUT/DELETE — those may have side effects.
/// - Retries on network errors (timeouts, connection drops) and 5xx server
///   responses (500/502/503/504) — which are typically transient.
/// - Explicit opt-in for non-idempotent requests via
///   `Options(extra: {RetryInterceptor.retryable: true})`.
/// - Explicit opt-out via `Options(extra: {RetryInterceptor.noRetry: true})`.
/// - Max 2 retries (3 attempts total) by default.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 400),
  }) : _dio = dio;

  /// The Dio instance this interceptor is attached to. Retries go back
  /// through the *same* interceptor chain so auth headers get re-attached.
  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  static const String retryable = 'retryable';
  static const String noRetry = 'noRetry';
  static const String _attemptKey = '__rent95_retry_attempt__';

  final Random _rand = Random();

  bool _isIdempotent(String method) {
    final m = method.toUpperCase();
    return m == 'GET' || m == 'HEAD' || m == 'OPTIONS';
  }

  bool _shouldRetry(DioException err) {
    final req = err.requestOptions;
    if (req.extra[noRetry] == true) return false;
    final canRetryMethod = req.extra[retryable] == true || _isIdempotent(req.method);
    if (!canRetryMethod) return false;

    // Network errors …
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    // … and transient 5xx.
    final code = err.response?.statusCode ?? 0;
    return code == 500 || code == 502 || code == 503 || code == 504;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final attempt = (req.extra[_attemptKey] as int?) ?? 0;

    if (attempt >= maxRetries || !_shouldRetry(err)) {
      return handler.next(err);
    }

    // Exponential backoff with jitter: 0.4s → 0.8s → 1.6s + up to 200 ms jitter.
    final delay = baseDelay * (1 << attempt);
    final jitter = Duration(milliseconds: _rand.nextInt(200));
    await Future<void>.delayed(delay + jitter);

    final newExtra = Map<String, dynamic>.from(req.extra)
      ..[_attemptKey] = attempt + 1;

    try {
      final response = await _dio.request<dynamic>(
        req.path,
        data: req.data,
        queryParameters: req.queryParameters,
        cancelToken: req.cancelToken,
        options: Options(
          method: req.method,
          headers: req.headers,
          extra: newExtra,
          responseType: req.responseType,
          contentType: req.contentType,
          followRedirects: req.followRedirects,
          receiveDataWhenStatusError: req.receiveDataWhenStatusError,
          sendTimeout: req.sendTimeout,
          receiveTimeout: req.receiveTimeout,
        ),
      );
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (_) {
      return handler.next(err);
    }
  }
}
