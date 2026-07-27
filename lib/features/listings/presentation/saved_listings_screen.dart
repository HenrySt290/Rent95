import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/components/listing_card.dart';
import '../../home/presentation/home_providers.dart';
import '../../../shared/services/mock_store.dart';

class SavedListingsScreen extends ConsumerWidget {
  const SavedListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoriteIdsProvider);
    final store = ref.read(mockStoreProvider);
    final favs = store.listings.where((l) => favIds.contains(l.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved listings')),
      body: favs.isEmpty
          ? const EmptyStateView(
              icon: Icons.favorite_outline,
              title: 'No saved listings',
              message: 'Tap the heart on any listing to save it here.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72,
              ),
              itemBuilder: (_, i) => ListingCard(
                listing: favs[i],
                isFavorite: true,
                onFavoriteToggle: () => ref.read(favoriteIdsProvider.notifier).toggle(favs[i].id),
              ),
            ),
    );
  }
}
