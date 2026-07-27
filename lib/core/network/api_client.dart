import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/env.dart';
import '../errors/app_exception.dart';
import '../storage/token_storage.dart';

/// Provides a configured Dio instance for the app.
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient.create(storage: storage);
});

class ApiClient {
  static Dio create({required TokenStorage storage}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(_AuthInterceptor(storage));
    dio.interceptors.add(_ErrorInterceptor());
    if (Env.isDev) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) {
            // ignore: avoid_print
            print(obj);
          },
        ),
      );
    }
    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final TokenStorage _storage;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final ex = _toAppException(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: ex,
        response: err.response,
        type: err.type,
        message: ex.message,
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
    final serverMessage = (data is Map && data['message'] is String)
        ? data['message'] as String
        : null;
    switch (status) {
      case 401:
        return const UnauthorizedException();
      case 403:
        return ForbiddenException(serverMessage ?? 'Forbidden');
      case 404:
        return NotFoundException(serverMessage ?? 'Not found');
      case 422:
        final fields = <String, String>{};
        if (data is Map && data['errors'] is Map) {
          (data['errors'] as Map).forEach((k, v) {
            fields[k.toString()] = v is List ? v.join(', ') : v.toString();
          });
        }
        return ValidationException(
          serverMessage ?? 'Please check your input.',
          fields: fields,
        );
      default:
        return ServerException(serverMessage ?? 'Server error');
    }
  }
}
