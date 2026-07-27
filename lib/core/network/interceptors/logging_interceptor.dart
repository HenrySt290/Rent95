import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Structured request/response logger. Never logs auth headers or refresh tokens.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({Logger? logger}) : _logger = logger ?? Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
  final Logger _logger;

  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };

  Map<String, dynamic> _scrubHeaders(Map<String, dynamic> headers) {
    return {
      for (final e in headers.entries)
        e.key: _sensitiveHeaders.contains(e.key.toLowerCase()) ? '[REDACTED]' : e.value,
    };
  }

  Object? _scrubBody(Object? body) {
    if (body is Map) {
      return {
        for (final e in body.entries)
          e.key: _isSensitiveField(e.key.toString()) ? '[REDACTED]' : e.value,
      };
    }
    return body;
  }

  bool _isSensitiveField(String key) {
    final k = key.toLowerCase();
    return k.contains('password') ||
        k.contains('token') ||
        k.contains('secret') ||
        k == 'otp' ||
        k == 'code';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d(
      '→ ${options.method} ${options.uri}\n'
      '  headers: ${_scrubHeaders(options.headers)}\n'
      '  body: ${_scrubBody(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _logger.i(
      '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.w(
      '✗ ${err.response?.statusCode ?? '?'} ${err.requestOptions.method} '
      '${err.requestOptions.uri}\n'
      '  message: ${err.message}\n'
      '  body: ${err.response?.data}',
    );
    handler.next(err);
  }
}
