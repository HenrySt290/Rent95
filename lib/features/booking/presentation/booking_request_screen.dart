import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/order.dart';
import '../../listings/presentation/listing_providers.dart';
import '../../orders/data/order_providers.dart';
import '../../orders/data/order_repository.dart';

class BookingRequestScreen extends ConsumerStatefulWidget {
  const BookingRequestScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends ConsumerState<BookingRequestScreen> {
  DateTime? _start;
  DateTime? _end;
  int _quantity = 1;
  String _delivery = 'pickup';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listingByIdProvider(widget.listingId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (listing) {
        if (listing == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Listing not found')));
        }
        return _buildBody(listing);
      },
    );
  }

  Widget _buildBody(Listing listing) {
    final days = (_start != null && _end != null)
        ? _end!.difference(_start!).inDays.clamp(1, 365)
        : 1;
    final isRental =
        listing.listingType == ListingType.rent || listing.listingType == ListingType.hybrid;
    final subtotal = listing.priceUnit == PriceUnit.fixed
        ? listing.price * _quantity
        : listing.price * (isRental ? days : 1) * _quantity;
    final fee = subtotal * 0.10;
    final tax = subtotal * 0.08;
    final total = subtotal + fee + tax + listing.securityDeposit;

    return Scaffold(
      appBar: AppBar(title: const Text('Book')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                if (listing.images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(listing.images.first,
                        width: 56, height: 56, fit: BoxFit.cover),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${Formatters.currency(listing.price)}${listing.priceUnitLabel}',
                        style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            if (isRental) ...[
              const SizedBox(height: 20),
              const Text('Select dates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: TableCalendar<Object>(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _start ?? DateTime.now(),
                  rangeStartDay: _start,
                  rangeEndDay: _end,
                  rangeSelectionMode: RangeSelectionMode.toggledOn,
                  onRangeSelected: (start, end, focused) {
                    setState(() {
                      _start = start;
                      _end = end;
                    });
                  },
                  calendarStyle: const CalendarStyle(
                    rangeHighlightColor: Color(0x333B49DF),
                    rangeStartDecoration:
                        BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    rangeEndDecoration:
                        BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    todayDecoration:
                        BoxDecoration(color: Color(0x333B49DF), shape: BoxShape.circle),
                  ),
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Quantity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              IconButton.outlined(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 16),
              Text('$_quantity',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              IconButton.outlined(
                onPressed:
                    _quantity < listing.quantity ? () => setState(() => _quantity++) : null,
                icon: const Icon(Icons.add),
              ),
              const Spacer(),
              Text('${listing.quantity} available',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 20),
            const Text('Delivery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: listing.deliveryOptions
                  .map((o) => ChoiceChip(
                        label: Text(_deliveryLabel(o)),
                        selected: _delivery == o,
                        onSelected: (_) => setState(() => _delivery = o),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Price breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  _priceRow('Subtotal', subtotal),
                  _priceRow('Service fee (10%)', fee),
                  _priceRow('Tax (est.)', tax),
                  if (listing.securityDeposit > 0)
                    _priceRow('Security deposit (refundable)', listing.securityDeposit),
                  const Divider(height: 20),
                  _priceRow('Total', total, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : () => _submit(listing),
              child: _submitting
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Confirm and pay ${Formatters.currency(total)}'),
            ),
            const SizedBox(height: 8),
            const Text(
              "You won't be charged until the seller accepts your request.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(Listing listing) async {
    setState(() => _submitting = true);
    try {
      final draft = OrderDraft(
        productId: listing.id,
        orderType: switch (listing.listingType) {
          ListingType.sale => OrderType.purchase,
          ListingType.service => OrderType.service,
          _ => OrderType.rental,
        },
        quantity: _quantity,
        startDate: _start,
        endDate: _end,
        deliveryMethod: _delivery,
      );
      final order = await ref.read(orderRepositoryProvider).create(draft);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.checkoutFor(order.id));
    } on AppException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _priceRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
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

  String _deliveryLabel(String o) {
    switch (o) {
      case 'delivery':
        return 'Delivery';
      case 'shipping':
        return 'Shipping';
      case 'on_site':
        return 'On site';
      default:
        return 'Pickup';
    }
  }
}
