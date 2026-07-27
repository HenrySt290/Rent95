import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/components/empty_state.dart';
import '../../../shared/components/listing_card.dart';
import '../../../shared/models/listing.dart';
import '../../home/presentation/home_providers.dart';
import '../data/listing_providers.dart';

/// Fetches the current favourites from the repository. We also keep the
/// [favoriteIdsProvider] in sync so cards elsewhere in the app stay accurate.
final _favoritesProvider = FutureProvider<List<Listing>>((ref) {
  return ref.watch(listingRepositoryProvider).favorites();
});

class SavedListingsScreen extends ConsumerWidget {
  const SavedListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(_favoritesProvider);
    final favIds = ref.watch(favoriteIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved listings')),
      body: favs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const EmptyStateView(
                icon: Icons.favorite_outline,
                title: 'No saved listings',
                message: 'Tap the heart on any listing to save it here.',
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_favoritesProvider);
                  await ref.read(_favoritesProvider.future);
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // Fixed cell height replaces childAspectRatio — see
                    // docs/DESIGN_AUDIT_FIXES.md R1.
                    mainAxisExtent: 300,
                  ),
                  itemBuilder: (_, i) => ListingCard(
                    listing: list[i],
                    isFavorite: favIds.contains(list[i].id),
                    onFavoriteToggle: () async {
                      await ref.read(favoriteIdsProvider.notifier).toggle(list[i].id);
                      ref.invalidate(_favoritesProvider);
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
