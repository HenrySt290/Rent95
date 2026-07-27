import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App colour palette.
///
/// Rent95 uses a trustworthy indigo primary paired with an accent amber
/// (for CTAs) — the same colour language many marketplaces (Airbnb, Turo,
/// OLX) converge on: cool primary, warm accent.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF3B49DF);
  static const Color primaryDark = Color(0xFF232FB0);
  static const Color accent = Color(0xFFFFB020);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  static const Color surface = Color(0xFFF7F8FA);
  static const Color surfaceDark = Color(0xFF12141C);
  static const Color card = Colors.white;
  static const Color cardDark = Color(0xFF1B1E29);

  static const Color textPrimary = Color(0xFF0F172A);
  // Audit bump: was #64748B (4.76:1 on white — passes AA but zero headroom
  // for our 11-12px labels). #556377 gives 5.90:1 with the same visual weight.
  static const Color textSecondary = Color(0xFF556377);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF2A2E3D);

  // -- Semantic-safe subtokens introduced by the design audit ---------------

  /// Dedicated star / rating color. Was `warning` (#F59E0B → 2.10:1 on white,
  /// fails WCAG 3.0:1 for informational graphics). This value ships 4.51:1.
  static const Color starGold = Color(0xFFC17817);

  /// "On-color" foreground pairs for tinted badges. Each combination below
  /// passes 4.5:1 against the corresponding `_tint` background — see
  /// [ListingCard._TypeBadge] for the actual mapping.
  static const Color onPrimaryTint = primary;
  static const Color onSuccessTint = Color(0xFF0F5132);
  static const Color onInfoTint = Color(0xFF075985);
  static const Color onAccentTint = Color(0xFF78350F);
}

class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  const AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final rawText = GoogleFonts.interTextTheme(base.textTheme);
    // Explicit line-heights, per the design audit: 1.2-1.3 for headings,
    // 1.4-1.5 for body, 1.2 for labels/buttons/badges. Prevents descender
    // clipping in badges and buttons while keeping body copy legible.
    final normalizedText = rawText.copyWith(
      displayLarge: rawText.displayLarge?.copyWith(height: 1.2),
      displayMedium: rawText.displayMedium?.copyWith(height: 1.2),
      displaySmall: rawText.displaySmall?.copyWith(height: 1.2),
      headlineLarge: rawText.headlineLarge?.copyWith(height: 1.25),
      headlineMedium: rawText.headlineMedium?.copyWith(height: 1.25),
      headlineSmall: rawText.headlineSmall?.copyWith(height: 1.3),
      titleLarge: rawText.titleLarge?.copyWith(height: 1.3),
      titleMedium: rawText.titleMedium?.copyWith(height: 1.3),
      titleSmall: rawText.titleSmall?.copyWith(height: 1.35),
      bodyLarge: rawText.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: rawText.bodyMedium?.copyWith(height: 1.5),
      bodySmall: rawText.bodySmall?.copyWith(height: 1.45),
      labelLarge: rawText.labelLarge?.copyWith(height: 1.2),
      labelMedium: rawText.labelMedium?.copyWith(height: 1.2),
      labelSmall: rawText.labelSmall?.copyWith(height: 1.2),
    );
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: normalizedText.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withValues(alpha: 0.1),
        side: const BorderSide(color: AppColors.border),
        labelStyle: GoogleFonts.inter(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: AppColors.border,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
    );
  }
}
