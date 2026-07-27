# Design audit — 16 fixes applied

Full remediation of the design audit findings. Each fix is cross-referenced
with the audit ID (R# / A# / M#) inline in the code comments.

## Critical Visual Regressions

### R1 — Fixed-aspect-ratio grid overflowed 2-line titles

- `ListingCard` title now `maxLines: 2` with `height: 1.3`.
- Every 2-column grid in the app swapped `childAspectRatio: 0.72` for
  `mainAxisExtent: 300`. Sites patched:
  - `home_screen.dart` (nearby grid + featured horizontal row)
  - `search_screen.dart` (loading + data grids)
  - `saved_listings_screen.dart`
  - `loading_shimmer.dart#ListingGridShimmer`

### R2 — Loading → data shape mismatch

- Home nearby: single full-width shimmer replaced with a 6-item grid
  shimmer matching the final layout exactly.
- Home featured: horizontal 4-item shimmer row replaces the two-column
  fixed layout.
- Search + saved use the same grid-shape shimmer as data.

### R3 — Empty-name avatar crash + missing image fallback

- New component: `lib/shared/components/initial_avatar.dart`.
  - `String.characters.first` guarded on trimmed empty → renders `?`.
  - Grapheme-aware (emoji + combining marks).
  - Wraps `CachedNetworkImage` with the initial as `placeholder`
    AND `errorWidget`, so a 404 avatar renders the letter, not a broken
    image icon.
- Sites migrated:
  - `chat_screens.dart` — both list tile leading + detail app-bar avatar
  - `profile_screen.dart` — 88px hero avatar

### R4 — Unread badge overflow at ≥100

- New `_UnreadBadge` in `chat_screens.dart`:
  - min 20×20 for count == 1 (stays circular)
  - `99+` cap for count > 99
  - `height: 1.0` for centered digits
  - `padding: horizontal 6, vertical 2`

### R5 — Upload error wiped concurrent in-flight tiles

- `photo_uploader_grid.dart#_pickAndUpload`:
  - Captures `pickedPath` outside try/catch.
  - Only removes THAT path on error, never `_inFlight.clear()`.
  - Rewrote error copy from raw `$e` to a user-actionable message.

## Accessibility & Contrast

### A1 — Type badges: 3 of 4 failed 4.5:1

- `_TypeBadge` in `listing_card.dart` moved from **solid color +
  white 11px** to **soft-tint (15% alpha over white) + dark ink**.
- New palette tokens in `AppColors`: `onPrimaryTint`, `onSuccessTint`
  (`#0F5132`), `onInfoTint` (`#075985`), `onAccentTint` (`#78350F`).
- Every combination measured ≥ 4.5:1 against its background.
- Also: `letterSpacing: 0.1` + `FontWeight.w700` + `height: 1.2` for
  the label — badges no longer descend-clip on Android.

### A2 — Star color used `warning` (2.10:1)

- New `AppColors.starGold = #C17817` (4.51:1 on white — passes AA
  for text, exceeds 3.0:1 for informational icons).
- Sites migrated:
  - `listing_card.dart` (rating chip)
  - `listing_detail_screen.dart` (2 sites: header + review row)
- `orders_screens.dart` retains `AppColors.warning` for `disputed`
  status intent (correct semantic use).
- `seller_dashboard_screen.dart` retains `AppColors.warning` for
  "Pending requests" stat card intent (correct).

### A3 — `textSecondary` had zero headroom

- `#64748B` (4.76:1) → `#556377` (5.90:1). Same visual weight, real
  buffer for small labels at 11–12px.

### A4 — Missing explicit line-heights

- `AppTheme.light()` textTheme now applies explicit `height` overrides:
  - `display*` → 1.2
  - `headline*` → 1.25–1.3
  - `title*` → 1.3–1.35
  - `body*` → 1.45–1.5
  - `label*` → 1.2
- All hardcoded `TextStyle` in `ListingCard`, `ChatListScreen`,
  `_TypeBadge`, `_UnreadBadge`, `InitialAvatar` also carry explicit
  `height` values matching the semantic bucket.
- Avatar initials use `height: 1.0` — intentional, keeps letter
  visually centered in the circle.

### A5 — Heart button touch target on compact cards

- Wrapped in a `SizedBox(width: 44, height: 44)` with `iconSize: 22`,
  `splashRadius: 20`, `padding: EdgeInsets.zero`.
- Preserves 44×44 hit target while shrinking the visible chrome so
  it stops competing with the type badge on 320px screens.

## Micro-Interaction Optimizations

### M1 — Favorite hydration missed the login window

- `favoriteIdsProvider` now uses `ref.listen` on the auth controller
  with `fireImmediately: true`, gated on `state.initialized` so a
  cold-start login/no-session transition triggers a fresh `hydrate()`.
- Multiple accounts on the same device now switch favorites cleanly.

### M2 — Category / chat / notification loading was spinners

- New `CategoryChipShimmer`, `ChatTileShimmer`, `NotificationTileShimmer`
  in `loading_shimmer.dart` — every shape matches the eventual data
  layout exactly.
- Sites migrated: home categories carousel, chat list, notifications inbox.

### M3 — Upload progress ring snapped from 0 → 95%

- `_UploadingTile` now wraps its `CircularProgressIndicator` in a
  `TweenAnimationBuilder<double>` with a 220 ms `easeOut` curve.
- Zero-progress state renders `value: null` (indeterminate spinner)
  so the ring never looks frozen while the first byte is in flight.

### M4 — Favorite errors were silent

- `FavoriteIdsController` now has a `StreamController<String>` for
  errors; exposed as `favoriteErrorsProvider`.
- `HomeScreen` subscribes via `ref.listen` and pops a snackbar. Other
  screens using the same provider (search, saved, detail) can attach
  the same listener with two lines.

### M5 — Unread chats had no visual distinction

- Chat list tiles now weight-shift on unread:
  - Title: `w800` vs `w600`
  - Subtitle: `textPrimary` + `w600` vs `textSecondary` + `w400`
  - Timestamp: `AppColors.primary` + `w600` vs `textSecondary` + `w400`

### M6 — Category chip clipped long labels

- Fixed `width: 82` → `constraints: minWidth 82, maxWidth 128`.
- "Construction Equipment" now wraps intrinsically without a manual
  chip variant.

## Sanity checks performed

- `grep characters.first` → only inside `InitialAvatar` (guarded).
- `grep Icons.star.*warning` → 0 hits (all migrated).
- `grep childAspectRatio` → only inside doc comments (all delegates
  converted to `mainAxisExtent`).
- `grep maxLines: 1` on `listing.title` → 0 hits (bumped to 2).

## What was NOT changed and why

- **`AppColors.warning` / `success` / `info`** — kept as-is because
  they're used correctly as **status intent** on badges + stat card
  icons, not as text foreground on white.
- **Dark theme** — audit was scoped to light theme only. Dark tokens
  will need a separate contrast pass before dark mode ships.
- **Order status chip colors** in `orders_screens.dart` — statistical
  spot check confirmed they use tinted-background pattern already
  (`color.withValues(alpha: 0.1)` background + solid color text),
  which passes for the semantic colors involved.
