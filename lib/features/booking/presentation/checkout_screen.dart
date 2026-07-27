import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/stripe_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/data/order_providers.dart';
import '../../payments/data/payment_providers.dart';

final _orderByIdProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, id) async {
  return ref.watch(orderRepositoryProvider).byId(id);
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _paying = false;
  String? _errorBanner;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_orderByIdProvider(widget.orderId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: _buildBody,
    );
  }

  Widget _buildBody(Order order) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorBanner != null) _ErrorBanner(message: _errorBanner!),
            _OrderSummaryCard(order: order),
            const SizedBox(height: 20),
            const Text('Payment method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            // Preview of what's inside the PaymentSheet. The actual selection
            // (card / Apple Pay / Google Pay / link) happens inside Stripe's
            // native sheet — we don't roll our own picker.
            const _PaymentMethodsPreview(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _paying ? null : () => _pay(order),
              child: _paying
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Pay ${Formatters.currency(order.totalAmount)}'),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Text('Secure escrow — funds held until you confirm',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('Powered by Stripe',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(Order order) async {
    setState(() {
      _paying = true;
      _errorBanner = null;
    });

    try {
      // 1. Ask the backend for a PaymentIntent. The server does the actual
      //    money math with Stripe Connect — the client never sees it.
      final intent = await ref
          .read(paymentRepositoryProvider)
          .createIntent(order.id);

      // 2. In pure-mock mode there is no Stripe SDK to open. Simulate the
      //    happy path so the local demo still feels realistic.
      if (Env.useMocks || Env.stripePublishableKey.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await ref
            .read(orderRepositoryProvider)
            .updateStatus(order.id, OrderStatus.paid);
        _showSuccessSheet(order);
        return;
      }

      // 3. Real mode: present Stripe's PaymentSheet. This blocks until the
      //    user completes, cancels, or the SDK errors.
      final email = ref.read(authControllerProvider).user?.email ?? '';
      final result = await ref.read(stripeServiceProvider).presentPaymentSheet(
            clientSecret: intent.clientSecret,
            customerEmail: email,
            currency: order.currency.toLowerCase(),
          );

      switch (result) {
        case PaymentSheetSuccess():
          // The Stripe webhook on the server flips the order to `paid`.
          // There's a short race between "PaymentSheet resolves on device"
          // and "webhook lands on backend". We invalidate the cache so the
          // order-detail screen refetches on entry, and the socket layer
          // will push an order_updated event within a second either way.
          ref.invalidate(_orderByIdProvider(order.id));
          ref.invalidate(ordersForCurrentUserProvider);
          _showSuccessSheet(order);

        case PaymentSheetCancelled():
          // User dismissed the sheet — no charge attempted. Silent no-op:
          // clear the loading state and let them try again.
          if (mounted) setState(() => _paying = false);

        case PaymentSheetFailed(:final message):
          _showError(message);
          if (mounted) setState(() => _paying = false);
      }
    } on AppException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _paying = false);
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _errorBanner = msg);
    // Also show a snackbar for immediate feedback — the banner stays put so
    // the user can read the details after the toast disappears.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessSheet(Order order) {
    if (!mounted) return;
    setState(() => _paying = false);
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 12),
            const Text('Payment successful',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'The seller has been notified. Track this booking any time from your orders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.orderDetailFor(order.id));
                },
                child: const Text('View order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Presentation-only widgets — kept private to this file.
// -----------------------------------------------------------------------------

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order ${order.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(order.productTitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const Divider(height: 20),
          _row('Subtotal', order.subtotal),
          _row('Service fee', order.platformFee),
          _row('Tax', order.taxAmount),
          if (order.securityDeposit > 0)
            _row('Deposit (refundable)', order.securityDeposit),
          const Divider(height: 20),
          _row('Total', order.totalAmount, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: bold ? style : style.copyWith(color: AppColors.textSecondary)),
          ),
          Text(Formatters.currency(amount), style: style),
        ],
      ),
    );
  }
}

class _PaymentMethodsPreview extends StatelessWidget {
  const _PaymentMethodsPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          _row(Icons.credit_card, 'Credit or debit card'),
          const Divider(height: 20),
          _row(Icons.apple, 'Apple Pay'),
          const Divider(height: 20),
          _row(Icons.account_balance_wallet, 'Google Pay'),
          const Divider(height: 20),
          const Text(
            "Pick your method on the next screen — we'll open Stripe's secure sheet.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 20, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
