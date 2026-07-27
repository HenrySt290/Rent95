import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../constants/app_constants.dart';
import '../constants/env.dart';

/// Result of a completed (or attempted) PaymentSheet flow.
///
/// We collapse Stripe's rich state model into three outcomes the app cares
/// about: success, user-cancelled, and everything-else-is-a-failure. This
/// matches the mental model of the checkout screen — you either finished
/// paying, decided not to, or something went wrong.
sealed class PaymentSheetResult {
  const PaymentSheetResult();
}

final class PaymentSheetSuccess extends PaymentSheetResult {
  const PaymentSheetSuccess();
}

final class PaymentSheetCancelled extends PaymentSheetResult {
  const PaymentSheetCancelled();
}

final class PaymentSheetFailed extends PaymentSheetResult {
  const PaymentSheetFailed({required this.message, this.code});
  final String message;
  final String? code;
}

/// Thin wrapper around `flutter_stripe`'s static `Stripe.instance` singleton.
///
/// Two reasons this exists as its own class:
///
/// 1. **Testability.** Feature code depends on the [StripeService] interface
///    via Riverpod, so tests can inject a fake without stubbing static
///    methods on the Stripe class.
///
/// 2. **Idempotent init.** `flutter_stripe`'s `Stripe.publishableKey =` and
///    `Stripe.instance.applySettings()` are cheap, but calling `applySettings`
///    twice from cold start causes a Xcode warning about `merchantIdentifier`
///    being set after PassKit registered. We guard both behind `_initialized`.
class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Called once at app start from `main.dart`. Safe to call again — the
  /// method short-circuits after the first successful init.
  ///
  /// If the publishable key is missing (e.g. `USE_MOCKS=true` and no
  /// `--dart-define`) this is a silent no-op. Attempting to open the
  /// PaymentSheet later will still throw a friendly [PaymentSheetFailed]
  /// so nothing crashes.
  Future<void> init() async {
    if (_initialized) return;
    final key = Env.stripePublishableKey;
    if (key.isEmpty) {
      if (Env.isDev) {
        // ignore: avoid_print
        print(
          '[Rent95] StripeService.init skipped — no STRIPE_PUBLISHABLE_KEY. '
          'Provide one via --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_… '
          'to enable real payments.',
        );
      }
      return;
    }

    Stripe.publishableKey = key;
    Stripe.merchantIdentifier = 'merchant.dev.rent95';
    Stripe.urlScheme = 'rent95';

    try {
      await Stripe.instance.applySettings();
      _initialized = true;
    } catch (e, st) {
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] Stripe.applySettings failed: $e\n$st');
      }
      // Leave _initialized = false so the next real call surfaces the error
      // to the user as a PaymentSheetFailed.
    }
  }

  /// Initialise and present the PaymentSheet in one go.
  ///
  /// Returns a [PaymentSheetResult] so the caller doesn't have to try/catch
  /// Stripe's [StripeException] hierarchy — every outcome is a value type.
  ///
  /// The [clientSecret] is what our backend returned from
  /// `POST /api/payments/create-intent`. It contains everything Stripe needs
  /// (amount, currency, capture method, application_fee, transfer_data.destination),
  /// so the mobile app doesn't need to know or repeat any of it.
  Future<PaymentSheetResult> presentPaymentSheet({
    required String clientSecret,
    required String customerEmail,
    required String currency,
  }) async {
    if (Env.stripePublishableKey.isEmpty) {
      return const PaymentSheetFailed(
        message: 'Payments are not configured yet. Please try again later.',
        code: 'stripe_not_configured',
      );
    }

    // Lazy re-init in case we skipped it at boot (e.g. keys arrived later).
    if (!_initialized) await init();
    if (!_initialized) {
      return const PaymentSheetFailed(
        message: 'Could not initialise Stripe. Please restart the app.',
        code: 'stripe_init_failed',
      );
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: AppConstants.appName,
          style: ThemeMode.light,
          billingDetails: BillingDetails(email: customerEmail),
          // Apple/Google Pay support. `merchantCountryCode` is required
          // whenever these are enabled — we default to US for MVP; when we
          // add Razorpay for India, that region gets its own PaymentSheet.
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: currency,
            testEnv: !Env.isProd,
          ),
          // Save-for-future-use is opt-in per booking; the buyer will see the
          // "Save for future use" checkbox inside the sheet when the seller
          // is a returning merchant. Leaving this default keeps things simple.
        ),
      );
    } on StripeException catch (e) {
      return PaymentSheetFailed(
        message: e.error.localizedMessage ?? e.error.message ?? 'Could not open the payment sheet.',
        code: e.error.code.name,
      );
    } catch (e) {
      return PaymentSheetFailed(message: 'Could not open the payment sheet: $e');
    }

    try {
      await Stripe.instance.presentPaymentSheet();
      return const PaymentSheetSuccess();
    } on StripeException catch (e) {
      // `Canceled` is a first-class outcome — the user tapped the X or the
      // system back gesture. Don't treat that as a real failure.
      if (e.error.code == FailureCode.Canceled) {
        return const PaymentSheetCancelled();
      }
      return PaymentSheetFailed(
        message: e.error.localizedMessage ?? e.error.message ?? 'Payment could not be completed.',
        code: e.error.code.name,
      );
    } catch (e) {
      return PaymentSheetFailed(message: 'Payment could not be completed: $e');
    }
  }
}

/// Riverpod handle. Kept as an interface-shaped provider so tests can
/// `overrideWithValue` a fake without touching the singleton.
final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService.instance;
});
