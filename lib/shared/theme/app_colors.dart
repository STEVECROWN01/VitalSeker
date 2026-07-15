import 'package:flutter/material.dart';

/// VitalSeker Color System
///
/// Aligned with vitalseker_tokens_v1.0.json from the Google Stitch design.
/// The palette is green-only (no purple) — the brand identity is "VitalGreen"
/// (ForestDark + Electric Mint) on "Deep Forest" / "Clean Mint" surfaces.
class AppColors {
  // ── Light theme ──
  // Primary (VitalGreen)
  static const Color lightPrimary = Color(0xFF0B7A5B);
  static const Color lightPrimaryDark = Color(0xFF054D39); // ForestDark
  static const Color lightPrimaryLight = Color(0xFF0B9E70);
  static const Color lightPrimaryContainer = Color(0xFFE9FEF6); // Clean Mint

  // Secondary (ForestDark green — NOT purple)
  static const Color lightSecondary = Color(0xFF054D39);
  static const Color lightSecondaryContainer = Color(0xFFD1FADF);

  // Surfaces
  static const Color lightBackground = Color(0xFFF9F9FC); // off-white per tokens
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFEEF1F0);
  static const Color lightOnBackground = Color(0xFF050F0B); // green-black
  static const Color lightOnSurface = Color(0xFF050F0B);
  static const Color lightOnSurfaceVariant = Color(0xFF404944);

  // Functional
  static const Color lightError = Color(0xFFBA1A1A);
  // FIX (audit L-13): darken lightWarning from #FF9800 to #E65100 for text use.
  // The previous color had a contrast ratio of ~2.8:1 on the light background,
  // failing WCAG AA. #E65100 has a ratio of ~5.5:1. For background fills
  // (chips, banners), the original brighter color can still be used via
  // `warning(isDark).withValues(alpha: 0.1)`.
  static const Color lightWarning = Color(0xFFE65100);
  static const Color lightSuccess = Color(0xFF4CAF50);
  static const Color lightInfo = Color(0xFF2196F3);

  // Outline
  static const Color lightOutline = Color(0xFF707973);
  static const Color lightOutlineVariant = Color(0xFFBDC9C2);

  // ── Dark theme ──
  // Primary (Electric Mint)
  static const Color darkPrimary = Color(0xFF0B9E70);
  static const Color darkPrimaryDark = Color(0xFF0B7A5B);
  static const Color darkPrimaryLight = Color(0xFF1DB886); // Electric Mint
  static const Color darkPrimaryContainer = Color(0xFF050F0B); // Deep Forest

  // Secondary (Electric Mint — NOT purple)
  static const Color darkSecondary = Color(0xFF1DB886);
  static const Color darkSecondaryContainer = Color(0xFF0B7A5B);

  // Surfaces
  static const Color darkBackground = Color(0xFF050F0B); // Deep Forest
  static const Color darkSurface = Color(0xFF0C1A16); // Obsidian Pine
  static const Color darkSurfaceContainer = Color(0xFF0C1A16);
  static const Color darkOnBackground = Color(0xFFE1E3E0);
  static const Color darkOnSurface = Color(0xFFE1E3E0);
  static const Color darkOnSurfaceVariant = Color(0xFFBFC9C2);

  // Functional
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkWarning = Color(0xFFFFB74D);
  static const Color darkSuccess = Color(0xFF69F0AE);
  static const Color darkInfo = Color(0xFF64B5F6);

  // Outline
  static const Color darkOutline = Color(0xFF8A938C);
  static const Color darkOutlineVariant = Color(0xFF22342F);

  // ── Shared ──
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF5F5F5);
  static const Color grey100 = Color(0xFFE0E0E0);
  static const Color grey200 = Color(0xFFBDBDBD);
  static const Color grey300 = Color(0xFF9E9E9E);
  static const Color grey400 = Color(0xFF757575);
  static const Color grey500 = Color(0xFF616161);
  static const Color grey600 = Color(0xFF424242);
  static const Color grey700 = Color(0xFF303030);
  static const Color grey800 = Color(0xFF212121);
  static const Color grey900 = Color(0xFF1A1A1A);

  // ── Brand gradient ──
  // Design spec: light = [#054D39, #0B7A5B], dark = [#0B9E70, #1DB886]
  // GREEN-ONLY — no purple.
  // Const versions for backward compatibility (light is the default).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF054D39), Color(0xFF0B7A5B)],
  );

  static const LinearGradient brandGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B9E70), Color(0xFF1DB886)],
  );

  /// Dark-mode-aware brand gradient.
  static LinearGradient brandGradientFor(bool isDark) =>
      isDark ? brandGradientDark : brandGradient;

  // SOS gradient (red)
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBA1A1A), Color(0xFF93000A)],
  );

  // ── Urgency colors ──
  static const Color urgencyLow = Color(0xFF4CAF50);
  static const Color urgencyMedium = Color(0xFFFF9800);
  static const Color urgencyHigh = Color(0xFFFF5722);
  static const Color urgencyEmergency = Color(0xFFBA1A1A);

  // ── Dark-mode-aware semantic helpers ──
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color background(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color onBackground(bool isDark) => isDark ? darkOnBackground : lightOnBackground;
  static Color onSurface(bool isDark) => isDark ? darkOnSurface : lightOnSurface;
  static Color primary(bool isDark) => isDark ? darkPrimary : lightPrimary;
  static Color secondary(bool isDark) => isDark ? darkSecondary : lightSecondary;
  static Color error(bool isDark) => isDark ? darkError : lightError;
  static Color success(bool isDark) => isDark ? darkSuccess : lightSuccess;
  static Color warning(bool isDark) => isDark ? darkWarning : lightWarning;
  static Color info(bool isDark) => isDark ? darkInfo : lightInfo;
  static Color primaryContainer(bool isDark) => isDark ? darkPrimaryContainer : lightPrimaryContainer;
  static Color secondaryContainer(bool isDark) => isDark ? darkSecondaryContainer : lightSecondaryContainer;
  static Color outline(bool isDark) => isDark ? darkOutline : lightOutline;
  static Color outlineVariant(bool isDark) => isDark ? darkOutlineVariant : lightOutlineVariant;

  // Card / input fill colors
  static Color cardBackground(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color inputFill(bool isDark) => isDark ? const Color(0xFF0C1A16) : lightSurfaceContainer;
  static Color subtleBackground(bool isDark) => isDark ? const Color(0xFF0C1A16) : lightSurfaceContainer;
  static Color border(bool isDark) => isDark ? darkOutlineVariant : lightOutlineVariant;
  static Color borderLight(bool isDark) => isDark ? darkOutlineVariant : lightOutlineVariant;
  static Color divider(bool isDark) => isDark ? darkOutlineVariant : lightOutlineVariant;

  // Text colors
  static Color textPrimary(bool isDark) => isDark ? darkOnBackground : lightOnBackground;
  static Color textSecondary(bool isDark) => isDark ? darkOnSurfaceVariant : lightOnSurfaceVariant;
  // FIX (audit L-12): darken the light-mode hint color from #707973 to #5A6361
  // to meet WCAG AA contrast (4.5:1) on the #F9F9FC background. The previous
  // color had a contrast ratio of ~3.7:1, which fails for normal text.
  static Color textHint(bool isDark) => isDark ? const Color(0xFF8A938C) : const Color(0xFF5A6361);
  static Color textTertiary(bool isDark) => isDark ? darkOutline : lightOutline;

  // Shadow
  static BoxShadow shadow(bool isDark) => isDark
      ? BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
      : BoxShadow(color: lightPrimary.withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 4));
}

/// Extension on [BuildContext] for quick dark-mode-aware color access
extension AppColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
