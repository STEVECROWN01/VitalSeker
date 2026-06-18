import 'package:flutter/material.dart';

/// VitalSeker Typography System
///
/// Aligned with vitalseker_tokens_v1.0.json + DESIGN.md from the Google Stitch design.
///
/// Font stack:
///   - Clash Display  (display/headlines — ExtraBold w800)
///   - Outfit          (titles — Bold w700)
///   - Inter           (body — Regular w400, line-height 1.6)
///   - DM Sans         (labels — Bold w700, uppercase, wide tracking)
///   - JetBrains Mono  (technical/data — Medium w500, 13px)
class AppTextStyles {
  // ── Clash Display — Headlines (ExtraBold w800) ──
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 32,
    fontWeight: FontWeight.w800, // ExtraBold per design
    height: 1.15,
    letterSpacing: -0.02, // -0.02em per design
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 26,
    fontWeight: FontWeight.w800, // ExtraBold
    height: 1.15,
    letterSpacing: -0.01,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 22,
    fontWeight: FontWeight.w800, // ExtraBold
    height: 1.2,
    letterSpacing: -0.01,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // ── Outfit — Titles (Bold w700) ──
  static const TextStyle subheading1 = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 18,
    fontWeight: FontWeight.w700, // Bold per design
    height: 1.3,
    letterSpacing: -0.01,
  );

  static const TextStyle subheading2 = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // ── Inter — Body (Regular w400, line-height 1.6) ──
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6, // 1.6 per DESIGN.md
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── DM Sans — Labels (Bold w700, uppercase, 0.05em tracking) ──
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    fontWeight: FontWeight.w700, // Bold per design
    height: 1.4,
    letterSpacing: 0.05, // 0.05em per design (≈0.7 at 14px)
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12,
    fontWeight: FontWeight.w700, // Bold
    height: 1.4,
    letterSpacing: 0.05, // 0.05em
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 10,
    fontWeight: FontWeight.w700, // Bold
    height: 1.4,
    letterSpacing: 0.05, // 0.05em
  );

  // ── JetBrains Mono — Technical (Medium w500, 13px) ──
  static const TextStyle monoRegular = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 13, // 13px per DESIGN.md (was 14)
    fontWeight: FontWeight.w500, // Medium per DESIGN.md (was w400)
    height: 1.4,
  );

  static const TextStyle monoSmall = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // ── DM Sans — Buttons (Bold w700, 14px) ──
  static const TextStyle button = TextStyle(
    fontFamily: 'DMSans', // DM Sans per DESIGN.md (was Outfit)
    fontSize: 14, // 14px per DESIGN.md (was 16)
    fontWeight: FontWeight.w700, // Bold
    height: 1.25,
    letterSpacing: 0.05,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0.03,
  );
}
