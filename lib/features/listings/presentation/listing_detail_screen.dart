import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/components/listing_card.dart';
import '../../../shared/models/listing.dart';
import '../../home/presentation/home_providers.dart';
import 'listing_providers.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listingByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Listing not found')),
          );
        }
        return _ListingDetailBody(listing: listing);
      },
    );
  }
}

class _ListingDetailBody extends ConsumerWidget {
  const _ListingDetailBody({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoriteIdsProvider);
    final isFav = favs.contains(listing.id);
    final reviews = ref.watch(reviewsForProductProvider(listing.id));
    final similar = ref.watch(similarListingsProvider(listing.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? AppColors.danger : null,
                ),
                onPressed: () => ref.read(favoriteIdsProvider.notifier).toggle(listing.id),
              ),
              IconButton(icon: const Icon(Icons.share), onPressed: () {}),
              PopupMenuButton<String>(
                onSelected: (_) {},
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Report listing')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: listing.images.length <= 1
                  ? (listing.images.isEmpty
                      ? Container(color: AppColors.border)
                      : CachedNetworkImage(imageUrl: listing.images.first, fit: BoxFit.cover))
                  : CarouselSlider(
                      options: CarouselOptions(
                        height: 320,
                        viewportFraction: 1,
                        enableInfiniteScroll: false,
                      ),
                      items: listing.images
                          .map((url) =>
                              CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity))
                          .toList(),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(listing.location.short,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    const Icon(Icons.star, color: AppColors.starGold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${listing.ratingAverage.toStringAsFixed(1)}  (${listing.reviewCount})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(listing.price),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (listing.priceUnitLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(listing.priceUnitLabel,
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ),
                      if (listing.securityDeposit > 0) ...[
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '+ ${Formatters.currency(listing.securityDeposit)} deposit',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(listing.ownerName,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Text('Verified seller',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.chatDetailFor('conv_001')),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('About this listing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(listing.description,
                      style: const TextStyle(height: 1.5, color: AppColors.textSecondary)),
                  if (listing.customAttributes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...listing.customAttributes.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e.key,
                                    style: const TextStyle(color: AppColors.textSecondary)),
                              ),
                              Text('${e.value}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 20),
                  const Text('Reviews',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  reviews.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (list) => list.isEmpty
                        ? const Text('No reviews yet.',
                            style: TextStyle(color: AppColors.textSecondary))
                        : Column(
                            children: list
                                .map((r) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                                            const SizedBox(width: 8),
                                            Text(r.reviewerName,
                                                style: const TextStyle(fontWeight: FontWeight.w600)),
                                            const Spacer(),
                                            const Icon(Icons.star, color: AppColors.starGold, size: 14),
                                            Text(' ${r.rating}',
                                                style: const TextStyle(fontWeight: FontWeight.w600)),
                                          ]),
                                          const SizedBox(height: 6),
                                          if (r.comment != null)
                                            Text(r.comment!,
                                                style: const TextStyle(color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                  similar.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Similar listings',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 240,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => SizedBox(
                                width: 200,
                                child: ListingCard(listing: list[i], compact: true),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.bookingRequestFor(listing.id)),
                child: Text(_primaryCtaLabel(listing.listingType)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _primaryCtaLabel(ListingType t) => switch (t) {
        ListingType.rent => 'Request to rent',
        ListingType.sale => 'Buy now',
        ListingType.service => 'Book service',
        ListingType.hybrid => 'Rent or buy',
      };
}
