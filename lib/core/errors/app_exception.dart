import 'package:flutter/foundation.dart';

/// Base class for typed application errors.
@immutable
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});
  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Session expired. Please log in again.'])
      : super(message, code: '401');
}

class ForbiddenException extends AppException {
  const ForbiddenException([String message = 'You are not allowed to do that.'])
      : super(message, code: '403');
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'Not found.']) : super(message, code: '404');
}

class ValidationException extends AppException {
  const ValidationException(super.message, {this.fields, super.code, super.cause});
  final Map<String, String>? fields;
}

class ServerException extends AppException {
  const ServerException([String message = 'Something went wrong. Please try again.'])
      : super(message, code: '500');
}

class CancelledException extends AppException {
  const CancelledException() : super('Request cancelled', code: 'cancelled');
}
