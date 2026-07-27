import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/components/empty_state.dart';
import '../../../shared/components/listing_card.dart';
import '../../../shared/components/loading_shimmer.dart';
import '../../../shared/models/listing.dart';
import '../../home/presentation/home_providers.dart';
import 'search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _keyword = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null) {
      Future.microtask(() {
        ref.read(searchFiltersProvider.notifier).state =
            SearchFilters(categoryId: widget.initialCategoryId);
      });
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final filters = ref.watch(searchFiltersProvider);
    final favs = ref.watch(favoriteIdsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyword,
                      onSubmitted: (v) => ref
                          .read(searchFiltersProvider.notifier)
                          .state = filters.copyWith(keyword: v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search anything…',
                        suffixIcon: _keyword.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _keyword.clear();
                                  ref.read(searchFiltersProvider.notifier).state =
                                      filters.copyWith(keyword: '');
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _openFilters(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            _ActiveFiltersBar(filters: filters),
            Expanded(
              child: results.when(
                loading: () => GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                    mainAxisExtent: 300,
                  ),
                  itemBuilder: (_, __) => const ListingCardShimmer(),
                ),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.search_off,
                      title: 'No results',
                      message: 'Try a different keyword or clear a filter.',
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                      mainAxisExtent: 300,
                    ),
                    itemBuilder: (_, i) => ListingCard(
                      listing: list[i],
                      isFavorite: favs.contains(list[i].id),
                      onFavoriteToggle: () =>
                          ref.read(favoriteIdsProvider.notifier).toggle(list[i].id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilters(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FiltersSheet(),
    );
  }
}

class _ActiveFiltersBar extends ConsumerWidget {
  const _ActiveFiltersBar({required this.filters});
  final SearchFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];
    if (filters.categoryId != null) {
      final cats = ref.watch(categoriesProvider).asData?.value ?? [];
      final name = cats.where((c) => c.id == filters.categoryId).map((c) => c.name).firstOrNull ?? 'Category';
      chips.add(_chip(name, () {
        ref.read(searchFiltersProvider.notifier).state = filters.copyWith(clearCategory: true);
      }));
    }
    if (filters.listingType != null) {
      chips.add(_chip(filters.listingType!.name, () {
        ref.read(searchFiltersProvider.notifier).state = filters.copyWith(clearType: true);
      }));
    }
    if (filters.minPrice != null || filters.maxPrice != null) {
      final label =
          '${filters.minPrice?.toStringAsFixed(0) ?? '0'} - ${filters.maxPrice?.toStringAsFixed(0) ?? '∞'}';
      chips.add(_chip(label, () {
        ref.read(searchFiltersProvider.notifier).state = filters.copyWith(minPrice: null, maxPrice: null);
      }));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();
  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late SearchFilters _draft;
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _city = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = ref.read(searchFiltersProvider);
    _min.text = _draft.minPrice?.toStringAsFixed(0) ?? '';
    _max.text = _draft.maxPrice?.toStringAsFixed(0) ?? '';
    _city.text = _draft.city ?? '';
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: cats
                  .map((c) => FilterChip(
                        label: Text(c.name),
                        selected: _draft.categoryId == c.id,
                        onSelected: (v) => setState(() {
                          _draft = _draft.copyWith(
                            categoryId: v ? c.id : null,
                            clearCategory: !v,
                          );
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ListingType.values
                  .map((t) => ChoiceChip(
                        label: Text(t.name),
                        selected: _draft.listingType == t,
                        onSelected: (v) => setState(() {
                          _draft = _draft.copyWith(
                            listingType: v ? t : null,
                            clearType: !v,
                          );
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Price range', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min', prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max', prefixText: '\$ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Location', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in const ['relevance', 'newest', 'price_asc', 'price_desc', 'rating'])
                  ChoiceChip(
                    label: Text(_sortLabel(s)),
                    selected: _draft.sort == s,
                    onSelected: (_) => setState(() => _draft = _draft.copyWith(sort: s)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(searchFiltersProvider.notifier).state = const SearchFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(searchFiltersProvider.notifier).state = _draft.copyWith(
                        minPrice: _min.text.isEmpty ? null : double.tryParse(_min.text),
                        maxPrice: _max.text.isEmpty ? null : double.tryParse(_max.text),
                        city: _city.text,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(String s) {
    switch (s) {
      case 'price_asc':
        return 'Price low → high';
      case 'price_desc':
        return 'Price high → low';
      case 'newest':
        return 'Newest';
      case 'rating':
        return 'Top rated';
      default:
        return 'Relevance';
    }
  }
}
