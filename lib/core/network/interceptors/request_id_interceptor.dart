import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Attaches a per-request `X-Request-Id` header for tracing, and lets callers
/// supply an `Idempotency-Key` via `Options(extra: {kIdempotencyKey: '…'})`.
///
/// Idempotency keys are the correct way to ensure that POST /orders and
/// POST /payments/create-intent don't create duplicates on retry — the API
/// records the key in `payments.idempotency_key`.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor([Uuid? uuid]) : _uuid = uuid ?? const Uuid();
  final Uuid _uuid;

  /// Callers use this to attach an idempotency key.
  ///   `dio.post('/api/orders', data: body,
  ///             options: Options(extra: {RequestIdInterceptor.idempotencyKey: uuid.v4()}))`
  static const String idempotencyKey = 'idempotencyKey';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-Id', _uuid.v4);
    final key = options.extra[idempotencyKey];
    if (key is String && key.isNotEmpty) {
      options.headers['Idempotency-Key'] = key;
    }
    handler.next(options);
  }
}
