import 'package:dio/dio.dart';

import '../../errors/app_exception.dart';

/// Maps every `DioException` to a typed [AppException] so feature code
/// only ever catches our domain errors, never Dio's low-level types.
///
/// Runs *after* [TokenRefreshInterceptor] so it doesn't intercept 401s that
/// could be recovered from.
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = _toAppException(err);
    // Preserve Dio's structural fields but attach our typed error.
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        message: mapped.message,
        error: mapped,
        stackTrace: err.stackTrace,
      ),
    );
  }

  AppException _toAppException(DioException err) {
    if (err.type == DioExceptionType.cancel) {
      return const CancelledException();
    }
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return NetworkException(err.message ?? 'Connection failed', cause: err);
    }

    final status = err.response?.statusCode;
    final data = err.response?.data;
    final serverMessage = _extractMessage(data);

    switch (status) {
      case 400:
        return ValidationException(serverMessage ?? 'Bad request');
      case 401:
        return UnauthorizedException(serverMessage ?? 'Session expired. Please log in again.');
      case 403:
        return ForbiddenException(serverMessage ?? 'You are not allowed to do that.');
      case 404:
        return NotFoundException(serverMessage ?? 'Not found');
      case 409:
        return ValidationException(serverMessage ?? 'Conflict', code: '409');
      case 422:
        return ValidationException(
          serverMessage ?? 'Please check your input.',
          fields: _extractFieldErrors(data),
        );
      case 429:
        return NetworkException(serverMessage ?? 'Too many requests. Please slow down.', code: '429');
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(serverMessage ?? 'Something went wrong on our end. Please try again.');
      default:
        return ServerException(serverMessage ?? 'Unexpected error (${status ?? 'no status'})');
    }
  }

  String? _extractMessage(Object? data) {
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) return m;
      final err = data['error'];
      if (err is String && err.isNotEmpty) return err;
    }
    return null;
  }

  Map<String, String>? _extractFieldErrors(Object? data) {
    if (data is Map && data['errors'] is Map) {
      final out = <String, String>{};
      (data['errors'] as Map).forEach((k, v) {
        if (v is List) {
          out[k.toString()] = v.join(', ');
        } else if (v != null) {
          out[k.toString()] = v.toString();
        }
      });
      return out.isEmpty ? null : out;
    }
    return null;
  }
}
