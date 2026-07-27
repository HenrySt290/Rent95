import 'payment_repository.dart';

/// A fake PaymentIntent flow. Waits a beat and returns a fabricated client
/// secret so the checkout screen can pretend to succeed.
class MockPaymentRepository implements PaymentRepository {
  @override
  Future<PaymentIntentResult> createIntent(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return PaymentIntentResult(
      clientSecret: 'mock_secret_$orderId',
      paymentIntentId: 'pi_mock_$orderId',
    );
  }
}
