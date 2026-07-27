import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Robust circular avatar.
///
/// Replaces the scattered `CircleAvatar(child: Text(name.characters.first))`
/// pattern which crashes with `StateError: No element` when the name is
/// empty or whitespace — a real edge case surfaced by the design audit
/// (deleted users, migration data, seed rows without a display name).
///
/// Handles:
///   - null / empty / whitespace-only [name] → renders '?'
///   - null / empty [imageUrl] → falls back to the initial
///   - remote image load failure → also falls back to the initial (no
///     broken-image icon flash)
///   - grapheme clusters ("😀 Bob" → 😀, "Å strid" → Å) — uses [Characters]
///     first, not [String.substring(0, 1)] which mangles surrogate pairs.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? name;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get _initial {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '?';
    // .characters handles emoji + combining marks correctly, unlike substring.
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary.withValues(alpha: 0.1);
    final fg = foregroundColor ?? AppColors.primary;

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _initial,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          // Radius-relative sizing keeps the letter proportional. height: 1.0
          // is intentional — anything larger and the letter no longer sits
          // on the visual centreline of the circle.
          fontSize: radius * 0.75,
          height: 1.0,
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    // We wrap the network image in a CachedNetworkImage so a 404 or a
    // slow-to-load avatar shows the initial fallback instead of a broken-
    // image icon during the load window.
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
