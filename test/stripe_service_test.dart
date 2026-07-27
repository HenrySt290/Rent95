import 'package:flutter_test/flutter_test.dart';

import 'package:rent95/core/services/stripe_service.dart';

void main() {
  group('PaymentSheetResult sealed hierarchy', () {
    test('success is a concrete singleton-like value', () {
      const result = PaymentSheetSuccess();
      expect(result, isA<PaymentSheetResult>());
      expect(result, isA<PaymentSheetSuccess>());
    });

    test('cancelled is a concrete distinct value', () {
      const result = PaymentSheetCancelled();
      expect(result, isA<PaymentSheetResult>());
      expect(result, isA<PaymentSheetCancelled>());
      expect(result, isNot(isA<PaymentSheetSuccess>()));
    });

    test('failed carries message and optional code', () {
      const result = PaymentSheetFailed(message: 'boom', code: 'x');
      expect(result.message, 'boom');
      expect(result.code, 'x');
    });

    test('exhaustive switch — the whole point of using a sealed class', () {
      // If a future contributor adds a new subtype without updating this
      // switch, the analyzer will complain. This test is here to make that
      // contract enforceable in CI.
      String describe(PaymentSheetResult r) => switch (r) {
            PaymentSheetSuccess() => 'ok',
            PaymentSheetCancelled() => 'cancel',
            PaymentSheetFailed(:final message) => 'fail: $message',
          };

      expect(describe(const PaymentSheetSuccess()), 'ok');
      expect(describe(const PaymentSheetCancelled()), 'cancel');
      expect(describe(const PaymentSheetFailed(message: 'nope')), 'fail: nope');
    });
  });

  group('StripeService.init', () {
    test('is safely a no-op when publishable key is empty', () async {
      // Default Env.stripePublishableKey in the test env is '' (no
      // --dart-define). init() should return cleanly and leave the service
      // uninitialised — subsequent calls to presentPaymentSheet then fail
      // with a friendly PaymentSheetFailed(code: stripe_not_configured).
      final svc = StripeService.instance;
      await svc.init();
      // Because there was no key, the service should NOT report initialised.
      expect(svc.isInitialized, false);
    });
  });

  group('StripeService.presentPaymentSheet without config', () {
    test('returns PaymentSheetFailed(stripe_not_configured)', () async {
      final svc = StripeService.instance;
      final result = await svc.presentPaymentSheet(
        clientSecret: 'pi_test_secret',
        customerEmail: 'a@b.c',
        currency: 'usd',
      );
      expect(result, isA<PaymentSheetFailed>());
      final failed = result as PaymentSheetFailed;
      expect(failed.code, 'stripe_not_configured');
      expect(failed.message, contains('not configured'));
    });
  });
}
