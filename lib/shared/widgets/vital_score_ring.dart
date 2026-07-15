import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
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
    final clamped = score.clamp(0, 100);
    if (clamped >= 80) return AppColors.urgencyLow;
    if (clamped >= 60) return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    if (clamped >= 40) return AppColors.urgencyMedium;
    if (clamped >= 20) return AppColors.urgencyHigh;
    return AppColors.urgencyEmergency;
  }

  /// FIX (audit L-10): use localized labels instead of hardcoded English.
  String _scoreLabel(AppLocalizations l10n) {
    final clamped = score.clamp(0, 100);
    if (clamped >= 80) return l10n.scoreLabelExcellent;
    if (clamped >= 60) return l10n.scoreLabelGood;
    if (clamped >= 40) return l10n.scoreLabelFair;
    if (clamped >= 20) return l10n.scoreLabelPoor;
    return l10n.scoreLabelCritical;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final color = _scoreColor(isDark);
    final label = _scoreLabel(l10n);

    final clampedValue = (score.clamp(0, 100)) / 100.0;

    return Semantics(
      label: '${l10n.vitalScore}: $score / 100, $label',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: clampedValue,
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
                    label,
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
      ),
    );
  }
}
