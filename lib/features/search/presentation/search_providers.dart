import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/listing.dart';
import '../../listings/data/listing_providers.dart';
import '../../listings/data/listing_repository.dart';

@immutable
class SearchFilters {
  const SearchFilters({
    this.keyword = '',
    this.categoryId,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.listingType,
    this.sort = 'relevance',
  });

  final String keyword;
  final String? categoryId;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final ListingType? listingType;
  final String sort;

  SearchFilters copyWith({
    String? keyword,
    String? categoryId,
    bool clearCategory = false,
    String? city,
    double? minPrice,
    double? maxPrice,
    ListingType? listingType,
    bool clearType = false,
    String? sort,
  }) {
    return SearchFilters(
      keyword: keyword ?? this.keyword,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      city: city ?? this.city,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      listingType: clearType ? null : (listingType ?? this.listingType),
      sort: sort ?? this.sort,
    );
  }
}

final searchFiltersProvider = StateProvider<SearchFilters>((_) => const SearchFilters());

final searchResultsProvider = FutureProvider.autoDispose<List<Listing>>((ref) async {
  final f = ref.watch(searchFiltersProvider);
  final repo = ref.watch(listingRepositoryProvider);
  return repo.search(
    ListingSearchQuery(
      keyword: f.keyword.isEmpty ? null : f.keyword,
      categoryId: f.categoryId,
      minPrice: f.minPrice,
      maxPrice: f.maxPrice,
      city: (f.city == null || f.city!.isEmpty) ? null : f.city,
      listingType: f.listingType,
      sort: f.sort,
    ),
  );
});
