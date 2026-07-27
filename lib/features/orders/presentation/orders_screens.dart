import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/models/order.dart';
import '../data/order_providers.dart';

final ordersForCurrentUserProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).myBuyerOrders();
});

final _orderByIdProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, id) async {
  return ref.watch(orderRepositoryProvider).byId(id);
});

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ordersForCurrentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const EmptyStateView(
                icon: Icons.shopping_bag_outlined,
                title: 'No orders yet',
                message: "When you book or buy something, it'll show up here.",
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ordersForCurrentUserProvider);
                  await ref.read(ordersForCurrentUserProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _OrderTile(order: list[i]),
                ),
              ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.push(AppRoutes.orderDetailFor(order.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: order.productImage.isEmpty
                  ? Container(width: 64, height: 64, color: AppColors.border)
                  : Image.network(
                      order.productImage, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(width: 64, height: 64, color: AppColors.border),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.productTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Order ${order.orderNumber}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _StatusChip(status: order.status),
                    const Spacer(),
                    Text(Formatters.currency(order.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.paid || OrderStatus.active => AppColors.primary,
      OrderStatus.completed => AppColors.success,
      OrderStatus.cancelled || OrderStatus.rejected => AppColors.danger,
      OrderStatus.disputed => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_orderByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (order) => _buildBody(context, ref, order),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Order order) {
    return Scaffold(
      appBar: AppBar(title: Text('Order ${order.orderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              if (order.productImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(order.productImage, width: 72, height: 72, fit: BoxFit.cover),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.productTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    _StatusChip(status: order.status),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (order.startDate != null && order.endDate != null)
            _infoTile(Icons.calendar_today, 'Dates',
                '${Formatters.date(order.startDate!)} → ${Formatters.date(order.endDate!)}'),
          _infoTile(Icons.person_outline, 'Seller', order.sellerName),
          _infoTile(Icons.local_shipping_outlined, 'Delivery', order.deliveryMethod),
          _infoTile(Icons.receipt_long_outlined, 'Total',
              Formatters.currency(order.totalAmount)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.messages),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message seller'),
          ),
          const SizedBox(height: 8),
          if (order.status == OrderStatus.active)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(orderRepositoryProvider)
                      .updateStatus(order.id, OrderStatus.completed);
                  ref.invalidate(_orderByIdProvider(order.id));
                  ref.invalidate(ordersForCurrentUserProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order marked as completed. Please leave a review.')),
                    );
                    context.pop();
                  }
                } on AppException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as completed'),
            ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }
}
