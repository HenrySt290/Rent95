import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/order.dart';
import '../../../shared/services/mock_store.dart';
import '../../auth/presentation/auth_controller.dart';

final _sellerListingsProvider = Provider<List<Listing>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  final store = ref.read(mockStoreProvider);
  if (user == null) return const [];
  return store.listings.where((l) => l.ownerId == user.id).toList();
});

final _sellerOrdersProvider = Provider<List<Order>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  final store = ref.read(mockStoreProvider);
  if (user == null) return const [];
  return store.orders.where((o) => o.sellerId == user.id).toList();
});

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(_sellerListingsProvider);
    final orders = ref.watch(_sellerOrdersProvider);
    final revenue = orders
        .where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.active)
        .fold<double>(0, (acc, o) => acc + o.subtotal * 0.9);
    final active = listings.where((l) => l.status == ListingStatus.active).length;
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            onPressed: () => context.go(AppRoutes.createListing),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(
                label: 'Revenue',
                value: Formatters.currency(revenue),
                icon: Icons.trending_up,
                color: AppColors.success,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                label: 'Active listings',
                value: '$active',
                icon: Icons.storefront,
                color: AppColors.primary,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(
                label: 'Pending requests',
                value: '$pending',
                icon: Icons.pending_actions,
                color: AppColors.warning,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                label: 'Rating',
                value: '4.8',
                icon: Icons.star,
                color: AppColors.accent,
              )),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Booking requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text('No booking requests yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...orders.map((o) => _RequestTile(order: o, ref: ref)),
          const SizedBox(height: 24),
          const Text('Your listings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (listings.isEmpty)
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.createListing),
              icon: const Icon(Icons.add),
              label: const Text('Create your first listing'),
            )
          else
            ...listings.map((l) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(l.images.first,
                            width: 56, height: 56, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('${Formatters.currency(l.price)}${l.priceUnitLabel} · ${l.location.short}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {},
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.order, required this.ref});
  final Order order;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final pending = order.status == OrderStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${order.buyerName} → ${order.productTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(Formatters.currency(order.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.startDate == null
                ? 'Requested ${Formatters.relative(order.createdAt)}'
                : '${Formatters.date(order.startDate!)} → ${Formatters.date(order.endDate!)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (pending) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(mockStoreProvider)
                        .updateOrderStatus(order.id, OrderStatus.rejected);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request declined')),
                      );
                    }
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(mockStoreProvider)
                        .updateOrderStatus(order.id, OrderStatus.accepted);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request accepted')),
                      );
                    }
                  },
                  child: const Text('Accept'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
