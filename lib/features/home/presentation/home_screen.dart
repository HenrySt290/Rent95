import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/components/category_chip.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/components/listing_card.dart';
import '../../../shared/components/loading_shimmer.dart';
import '../../../shared/models/listing.dart';
import '../../auth/presentation/auth_controller.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final featured = ref.watch(featuredListingsProvider);
    final nearby = ref.watch(nearbyListingsProvider);
    final user = ref.watch(authControllerProvider).user;
    final favs = ref.watch(favoriteIdsProvider);

    // Audit M4: surface silent favorite-toggle failures via a snackbar.
    // The optimistic rollback happens automatically in the controller;
    // this is only the visible acknowledgement to the user.
    ref.listen<AsyncValue<String>>(favoriteErrorsProvider, (previous, next) {
      final msg = next.valueOrNull;
      if (msg == null) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(featuredListingsProvider);
            ref.invalidate(nearbyListingsProvider);
            ref.invalidate(categoriesProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(userName: user?.fullName ?? 'there'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: InkWell(
                    onTap: () => context.go(AppRoutes.search),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: AppColors.textSecondary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search anything to rent, buy, or book',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          Icon(Icons.tune, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      TextButton(onPressed: () => context.go(AppRoutes.search), child: const Text('See all')),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: categories.when(
                    loading: () => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, __) => const CategoryChipShimmer(),
                    ),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (cats) => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: cats.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => CategoryChip(
                        label: cats[i].name,
                        iconName: cats[i].iconName,
                        onTap: () => context.push('${AppRoutes.search}?category=${cats[i].id}'),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _PromoBanner(onTap: () => context.go(AppRoutes.createListing))),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  title: 'Featured',
                  onSeeAll: () => context.go(AppRoutes.search),
                ),
              ),
              featured.when(
                loading: () => SliverToBoxAdapter(
                  child: SizedBox(
                    height: 296,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, __) => const SizedBox(
                        width: 220,
                        child: ListingCardShimmer(compact: true),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
                data: (list) => SliverToBoxAdapter(
                  child: SizedBox(
                    // Slightly taller than before to accommodate the audit's
                    // 2-line title fix — otherwise a real title like "Tesla
                    // Model 3 — Long Range" clips at compact widths.
                    height: 296,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => SizedBox(
                        width: 220,
                        child: ListingCard(
                          listing: list[i],
                          isFavorite: favs.contains(list[i].id),
                          onFavoriteToggle: () => ref
                              .read(favoriteIdsProvider.notifier)
                              .toggle(list[i].id),
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  title: 'Near you',
                  onSeeAll: () => context.go(AppRoutes.search),
                ),
              ),
              nearby.when(
                loading: () => SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // Fixed cell height matches the data grid below — no
                      // layout jolt when the data lands (audit R2).
                      mainAxisExtent: 300,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const ListingCardShimmer(),
                      childCount: 6,
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
                data: (list) {
                  if (list.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyStateView(
                        icon: Icons.map_outlined,
                        title: 'Nothing near you yet',
                        message: 'Try widening your search or check back later.',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        // Fixed cell height (audit R1). Was
                        // `childAspectRatio: 0.72` which forced a rigid
                        // aspect and overflowed on 2-line titles. 300px
                        // holds a 4:3 image + 2-line title + meta comfortably
                        // on 375px viewports.
                        mainAxisExtent: 300,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => ListingCard(
                        listing: list[i],
                        isFavorite: favs.contains(list[i].id),
                        onFavoriteToggle: () =>
                            ref.read(favoriteIdsProvider.notifier).toggle(list[i].id),
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context,
      {required String title, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('New York, NY', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Hi, $userName 👋',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Turn your stuff into income',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'List an item in 60 seconds. ${AppConstants.appName} handles payments.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Text(
                        'Start listing',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.storefront, size: 68, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
