import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';

/// Skeleton primitives — one shimmer per widget shape.
///
/// Introduced by the design audit to replace loose `CircularProgressIndicator`
/// spinners in list/grid loading states. Every dynamic surface in the app
/// should route through one of the widgets below during its `loading:`
/// branch so we never render a blank container.

/// Reusable shimmer wrapper. Base + highlight tuned to be visible on
/// [AppColors.surface] and [AppColors.card] alike.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: borderRadius ?? BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// Matches [ListingCard] proportions. Placed in a grid it produces a
/// shape-consistent loading state — no more single full-width shimmer
/// snapping into a two-column grid on completion.
class ListingCardShimmer extends StatelessWidget {
  const ListingCardShimmer({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: compact ? 16 / 10 : 4 / 3,
              child: Container(color: AppColors.border),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, color: AppColors.border),
                  const SizedBox(height: 6),
                  Container(height: 14, width: 120, color: AppColors.border),
                  const SizedBox(height: 12),
                  Container(height: 12, width: 100, color: AppColors.border),
                  const SizedBox(height: 12),
                  Container(height: 14, width: 60, color: AppColors.border),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal-scroll grid loading state that mirrors [CategoryChip].
class CategoryChipShimmer extends StatelessWidget {
  const CategoryChipShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: Colors.white,
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}

/// Matches the [ChatListScreen] tile shape: avatar + two text lines +
/// trailing meta. Keeping the exact shape prevents the "list rearranges
/// when data arrives" jank.
class ChatTileShimmer extends StatelessWidget {
  const ChatTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Shimmer.fromColors(
        baseColor: AppColors.border,
        highlightColor: Colors.white,
        child: Row(
          children: [
            const CircleAvatar(radius: 24, backgroundColor: AppColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: AppColors.border),
                  const SizedBox(height: 8),
                  Container(height: 12, color: AppColors.border),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 40, height: 12, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

/// Matches the [NotificationsScreen] tile shape.
class NotificationTileShimmer extends StatelessWidget {
  const NotificationTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Shimmer.fromColors(
        baseColor: AppColors.border,
        highlightColor: Colors.white,
        child: Row(
          children: [
            const CircleAvatar(radius: 20, backgroundColor: AppColors.border),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 13, width: 180, color: AppColors.border),
                  const SizedBox(height: 6),
                  Container(height: 11, color: AppColors.border),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed-count grid of [ListingCardShimmer], used in place of the
/// single-shimmer-then-grid mismatch on the home screen and search.
class ListingGridShimmer extends StatelessWidget {
  const ListingGridShimmer({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 300,
      ),
      itemBuilder: (_, __) => const ListingCardShimmer(),
    );
  }
}
