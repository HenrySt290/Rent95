import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/listing.dart';

/// Marketplace listing tile.
///
/// Notes on layout guarantees enforced here:
///   - Title accepts up to 2 lines, ellipsized on the third.
///   - No fixed inner heights — the card sizes to content. Callers that
///     put this in a grid must use `SliverGridDelegateWithMaxCrossAxisExtent`
///     with `mainAxisExtent`, NOT `childAspectRatio`, so multi-line titles
///     don't overflow the tile.
///   - Favourite tap target is 44x44 min per iOS HIG + Material guidelines,
///     even in compact mode.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.compact = false,
  });

  final Listing listing;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(AppRoutes.listingDetailFor(listing.id)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: compact ? 16 / 10 : 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      child: listing.images.isEmpty
                          ? Container(color: AppColors.border)
                          : CachedNetworkImage(
                              imageUrl: listing.images.first,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: AppColors.border),
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: AppColors.border,
                                child: Center(
                                  child: Icon(Icons.image_not_supported_outlined,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      // Constrain badge width so a longer label
                      // ("Rent or buy") can't collide with the heart icon.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: _TypeBadge(type: listing.listingType),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 22,
                          splashRadius: 20,
                          tooltip: isFavorite ? 'Remove from saved' : 'Save',
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? AppColors.danger : Colors.white,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                          onPressed: onFavoriteToggle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3, // audit fix — was default (~1.15)
                      ),
                      // Two lines with ellipsis: real product titles like
                      // "Tesla Model 3 — Long Range with Autopilot" need
                      // breathing room. The grid delegate ensures the tile
                      // absorbs the extra line without overflowing.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            listing.location.short,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Wrap the price + unit together so a long
                        // "$3,200 / month" doesn't push the rating off-card.
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  Formatters.currency(listing.price),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (listing.priceUnitLabel.isNotEmpty)
                                Text(
                                  listing.priceUnitLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (listing.reviewCount > 0)
                          _RatingChip(
                            rating: listing.ratingAverage,
                            reviewCount: listing.reviewCount,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.reviewCount});
  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 14, color: AppColors.starGold),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
        ),
        Text(
          ' ($reviewCount)',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
        ),
      ],
    );
  }
}

/// Soft-tint pill badges. Every combination below passes WCAG AA 4.5:1
/// (audit A1). Was: solid coloured backgrounds + white 11px text, three of
/// which failed contrast — see `docs/DESIGN_AUDIT_FIXES.md`.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final ListingType type;

  static Color _tint(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.15), Colors.white);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (type) {
      ListingType.rent => (
          'For rent',
          _tint(AppColors.primary),
          AppColors.onPrimaryTint,
        ),
      ListingType.sale => (
          'For sale',
          _tint(AppColors.success),
          AppColors.onSuccessTint,
        ),
      ListingType.service => (
          'Service',
          _tint(AppColors.info),
          AppColors.onInfoTint,
        ),
      ListingType.hybrid => (
          'Rent or buy',
          _tint(AppColors.accent),
          AppColors.onAccentTint,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // Subtle border helps the pill separate from busy product images.
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
