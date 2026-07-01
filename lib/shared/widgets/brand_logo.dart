import 'package:flutter/material.dart';

/// Reusable VitalSeker brand logo widget.
///
/// Renders the official VitalSeker logo PNG from
/// `assets/images/branding/app_logo.png` inside an optionally-styled
/// container (gradient background, rounded corners, shadow).
///
/// Use this everywhere the brand identity needs to appear:
/// splash screen, login screen, about screen, passport header, etc.
///
/// Replaces the old programmatic logo (Icons.favorite_rounded + Icons.add
/// in a Stack) with the actual designed logo asset.
class BrandLogo extends StatelessWidget {
  /// Side length in logical pixels. The logo is always rendered as a square.
  final double size;

  /// Whether to render the gradient container background behind the logo.
  /// If `false`, only the logo image is shown (useful for inline placement
  /// in headers where the gradient would clash with the surrounding card).
  final bool showContainer;

  /// Whether to render the drop shadow behind the container.
  /// Ignored when [showContainer] is `false`.
  final bool showShadow;

  /// Border radius of the container. Defaults to 28 (matches the splash
  /// screen's design token `radius-lg`).
  /// Ignored when [showContainer] is `false`.
  final double borderRadius;

  /// Optional override for the logo asset path. Defaults to the full brand
  /// logo. Useful for testing or for using the icon-only variant.
  final String? assetPath;

  const BrandLogo({
    super.key,
    required this.size,
    this.showContainer = true,
    this.showShadow = true,
    this.borderRadius = 28,
    this.assetPath,
  });

  /// Compact variant for inline use (e.g. in headers, next to app name).
  /// No container, no shadow — just the logo image.
  const BrandLogo.inline({
    super.key,
    required this.size,
    this.assetPath,
  })  : showContainer = false,
        showShadow = false,
        borderRadius = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = Image.asset(
      assetPath ?? 'assets/images/branding/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Prevent the image from flickering on rebuilds
      gaplessPlayback: true,
    );

    if (!showContainer) {
      return SizedBox(width: size, height: size, child: logo);
    }

    // Gradient container — mirrors the splash screen's brand treatment
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0B7A5B), const Color(0xFF054D39)]
              : [const Color(0xFF10B981), const Color(0xFF0B7A5B)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF0B7A5B).withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Padding(
        // Inner padding so the logo breathes inside the container
        padding: EdgeInsets.all(size * 0.15),
        child: logo,
      ),
    );
  }
}
