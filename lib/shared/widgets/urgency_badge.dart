import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';

class UrgencyBadge extends StatelessWidget {
  final String urgencyLevel;
  final double? fontSize;

  const UrgencyBadge({
    super.key,
    required this.urgencyLevel,
    this.fontSize,
  });

  Color _color(bool isDark) {
    switch (urgencyLevel.toLowerCase()) {
      case 'low': return AppColors.urgencyLow;
      case 'medium': return AppColors.urgencyMedium;
      case 'high': return AppColors.urgencyHigh;
      case 'emergency': return AppColors.urgencyEmergency;
      default: return isDark ? AppColors.grey300 : AppColors.grey400;
    }
  }

  IconData get _icon {
    switch (urgencyLevel.toLowerCase()) {
      case 'low': return Icons.check_circle_outline;
      case 'medium': return Icons.warning_amber_rounded;
      case 'high': return Icons.error_outline_rounded;
      case 'emergency': return Icons.emergency_rounded;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // FIX (audit M-29): wrap in Semantics so screen readers announce
    // "Urgency level: emergency" instead of just "EMERGENCY".
    return Semantics(
      label: 'Urgency level: $urgencyLevel',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _color(isDark).withValues(alpha: isDark ? 0.25 : 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color(isDark).withValues(alpha: isDark ? 0.5 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 16, color: _color(isDark)),
            const SizedBox(width: 6),
            Text(
              urgencyLevel.toUpperCase(),
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: fontSize ?? 11,
                fontWeight: FontWeight.w700,
                color: _color(isDark),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
