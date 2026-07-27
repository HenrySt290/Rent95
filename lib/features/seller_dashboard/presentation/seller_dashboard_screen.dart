import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/order.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../listings/data/listing_providers.dart';
import '../../listings/data/listing_repository.dart';
import '../../orders/data/order_providers.dart';

final _sellerListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final userId = ref.watch(authControllerProvider).user?.id;
  if (userId == null) return const [];
  // Server-side we'd have a dedicated /seller/products endpoint. For MVP we
  // reuse the public search and filter client-side by owner id.
  final repo = ref.watch(listingRepositoryProvider);
  final all = await repo.search(const ListingSearchQuery(pageSize: 50, sort: 'newest'));
  return all.where((l) => l.ownerId == userId).toList(growable: false);
});

final _sellerOrdersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).mySellerOrders();
});

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(_sellerListingsProvider);
    final orders = ref.watch(_sellerOrdersProvider);

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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_sellerListingsProvider);
          ref.invalidate(_sellerOrdersProvider);
          await Future.wait<void>([
            ref.read(_sellerListingsProvider.future),
            ref.read(_sellerOrdersProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatsRow(listings: listings, orders: orders),
            const SizedBox(height: 24),
            const Text('Booking requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            orders.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Text('No booking requests yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return Column(children: [
                  for (final o in list) _RequestTile(order: o),
                ]);
              },
            ),
            const SizedBox(height: 24),
            const Text('Your listings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            listings.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) {
                  return OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.createListing),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first listing'),
                  );
                }
                return Column(children: [
                  for (final l in list) _ListingRow(listing: l),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.listings, required this.orders});
  final AsyncValue<List<Listing>> listings;
  final AsyncValue<List<Order>> orders;

  @override
  Widget build(BuildContext context) {
    final activeListings = listings.maybeWhen(
      data: (list) => list.where((l) => l.status == ListingStatus.active).length,
      orElse: () => 0,
    );
    final pending = orders.maybeWhen(
      data: (list) => list.where((o) => o.status == OrderStatus.pending).length,
      orElse: () => 0,
    );
    final revenue = orders.maybeWhen(
      data: (list) => list
          .where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.active)
          .fold<double>(0, (acc, o) => acc + o.subtotal * 0.9),
      orElse: () => 0.0,
    );

    return Column(children: [
      Row(children: [
        Expanded(child: _StatCard(
          label: 'Revenue',
          value: Formatters.currency(revenue),
          icon: Icons.trending_up,
          color: AppColors.success,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          label: 'Active listings',
          value: '$activeListings',
          icon: Icons.storefront,
          color: AppColors.primary,
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _StatCard(
          label: 'Pending requests',
          value: '$pending',
          icon: Icons.pending_actions,
          color: AppColors.warning,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          label: 'Rating',
          value: '—',
          icon: Icons.star,
          color: AppColors.accent,
        )),
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
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

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onPressed: () => _respond(context, ref, OrderStatus.rejected, 'Request declined'),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respond(context, ref, OrderStatus.accepted, 'Request accepted'),
                  child: const Text('Accept'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    OrderStatus next,
    String successMessage,
  ) async {
    try {
      await ref.read(orderRepositoryProvider).updateStatus(order.id, next);
      ref.invalidate(_sellerOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
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
                  '${Formatters.currency(listing.price)}${listing.priceUnitLabel} · ${listing.location.short}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
