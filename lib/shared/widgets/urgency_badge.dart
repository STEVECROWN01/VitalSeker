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

  Color get _color {
    switch (urgencyLevel.toLowerCase()) {
      case 'low': return AppColors.urgencyLow;
      case 'medium': return AppColors.urgencyMedium;
      case 'high': return AppColors.urgencyHigh;
      case 'emergency': return AppColors.urgencyEmergency;
      default: return AppColors.grey400;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 16, color: _color),
          const SizedBox(width: 6),
          Text(
            urgencyLevel.toUpperCase(),
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w700,
              color: _color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
