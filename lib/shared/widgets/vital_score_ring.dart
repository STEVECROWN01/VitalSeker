import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';

class VitalScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final bool showLabel;

  const VitalScoreRing({
    super.key,
    required this.score,
    this.size = 120,
    this.showLabel = true,
  });

  Color _scoreColor(bool isDark) {
    if (score >= 80) return AppColors.urgencyLow;
    if (score >= 60) return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    if (score >= 40) return AppColors.urgencyMedium;
    if (score >= 20) return AppColors.urgencyHigh;
    return AppColors.urgencyEmergency;
  }

  String get _scoreLabel {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Poor';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _scoreColor(isDark);
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: size * 0.08,
              backgroundColor: AppColors.subtleBackground(isDark),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (showLabel)
                Text(
                  _scoreLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: size * 0.09,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
