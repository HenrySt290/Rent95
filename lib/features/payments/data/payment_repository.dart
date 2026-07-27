/// Payment intent handed back to the client to complete via the Stripe SDK.
class PaymentIntentResult {
  const PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
  });
  final String clientSecret;
  final String paymentIntentId;
}

/// Data source for creating and confirming payments.
///
/// In the real implementation this hits `POST /api/payments/create-intent`,
/// which asks Stripe (via Stripe Connect) for a PaymentIntent. The mobile
/// app then presents the Stripe PaymentSheet, which handles card details on
/// the client without them ever touching our server.
abstract class PaymentRepository {
  Future<PaymentIntentResult> createIntent(String orderId);
}
