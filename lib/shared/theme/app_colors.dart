import 'package:flutter/material.dart';

class AppColors {
  // Light theme
  static const Color lightPrimary = Color(0xFF0B7A5B);
  static const Color lightPrimaryDark = Color(0xFF096549);
  static const Color lightPrimaryLight = Color(0xFF0B9E70);
  static const Color lightBackground = Color(0xFFF8FAFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnBackground = Color(0xFF1A1A2E);
  static const Color lightOnSurface = Color(0xFF1A1A2E);
  static const Color lightSecondary = Color(0xFF6C63FF);
  static const Color lightError = Color(0xFFE53935);
  static const Color lightWarning = Color(0xFFFF9800);
  static const Color lightSuccess = Color(0xFF4CAF50);
  static const Color lightInfo = Color(0xFF2196F3);
  
  // Dark theme
  static const Color darkPrimary = Color(0xFF0B9E70);
  static const Color darkPrimaryDark = Color(0xFF097A56);
  static const Color darkPrimaryLight = Color(0xFF0DC48A);
  static const Color darkBackground = Color(0xFF0A0E17);
  static const Color darkSurface = Color(0xFF151925);
  static const Color darkOnBackground = Color(0xFFE8ECF1);
  static const Color darkOnSurface = Color(0xFFE8ECF1);
  static const Color darkSecondary = Color(0xFF8B83FF);
  static const Color darkError = Color(0xFFFF5252);
  static const Color darkWarning = Color(0xFFFFB74D);
  static const Color darkSuccess = Color(0xFF69F0AE);
  static const Color darkInfo = Color(0xFF64B5F6);
  
  // Shared
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
  
  // Brand gradient
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B7A5B), Color(0xFF0B9E70), Color(0xFF6C63FF)],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Urgency colors
  static const Color urgencyLow = Color(0xFF4CAF50);
  static const Color urgencyMedium = Color(0xFFFF9800);
  static const Color urgencyHigh = Color(0xFFFF5722);
  static const Color urgencyEmergency = Color(0xFFE53935);
}
