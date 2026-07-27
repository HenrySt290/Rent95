import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/interceptors/request_id_interceptor.dart';
import 'payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._dio) : _uuid = const Uuid();
  final Dio _dio;
  final Uuid _uuid;

  @override
  Future<PaymentIntentResult> createIntent(String orderId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/payments/create-intent',
      data: {'orderId': orderId},
      // Belt-and-braces: server also uses `pi-<orderId>` as a native
      // idempotency key so retries reuse the same PaymentIntent.
      options: Options(extra: {RequestIdInterceptor.idempotencyKey: _uuid.v4()}),
    );
    final data = decodeObject(res, (m) => m);
    return PaymentIntentResult(
      clientSecret: data['clientSecret'] as String,
      paymentIntentId: data['paymentIntentId'] as String,
    );
  }
}
