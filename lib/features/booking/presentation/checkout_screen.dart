import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
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
  String _method = 'card';
  bool _paying = false;

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
            Container(
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
            ),
            const SizedBox(height: 20),
            const Text('Payment method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _methodTile('card', 'Credit or debit card', Icons.credit_card),
            _methodTile('apple_pay', 'Apple Pay', Icons.apple),
            _methodTile('google_pay', 'Google Pay', Icons.account_balance_wallet),
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
          ],
        ),
      ),
    );
  }

  Widget _methodTile(String value, String label, IconData icon) {
    final selected = _method == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _method,
        onChanged: (v) => setState(() => _method = v ?? _method),
        title: Text(label),
        secondary: Icon(icon),
        activeColor: AppColors.primary,
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
                  style: bold ? style : style.copyWith(color: AppColors.textSecondary))),
          Text(Formatters.currency(amount), style: style),
        ],
      ),
    );
  }

  Future<void> _pay(Order order) async {
    setState(() => _paying = true);
    try {
      // 1. Ask the backend for a PaymentIntent (via Stripe Connect).
      final intent = await ref.read(paymentRepositoryProvider).createIntent(order.id);

      // 2. TODO(payments): Present the Stripe PaymentSheet:
      //
      //   await Stripe.instance.initPaymentSheet(
      //     paymentSheetParameters: SetupPaymentSheetParameters(
      //       paymentIntentClientSecret: intent.clientSecret,
      //       merchantDisplayName: 'Rent95',
      //     ),
      //   );
      //   await Stripe.instance.presentPaymentSheet();
      //
      // For now we simulate a delay so the UX still feels real in mock mode.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      debugPrint('PaymentIntent created: ${intent.paymentIntentId}');

      // 3. Mark the order paid locally. In real mode the Stripe webhook
      // does this on the server, but we optimistically flip status so the
      // buyer sees the right thing on the order detail screen.
      await ref.read(orderRepositoryProvider).updateStatus(order.id, OrderStatus.paid);
    } on AppException catch (e) {
      _showError(e.message);
      setState(() => _paying = false);
      return;
    } catch (e) {
      _showError(e.toString());
      setState(() => _paying = false);
      return;
    }

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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
