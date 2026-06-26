import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// A reusable medical disclaimer banner.
///
/// Per the VitalSeker Cahier des Charges Section 7 (Security & Compliance):
/// "Chaque écran de résultat affiche : 'Ces informations ne constituent pas
/// un diagnostic médical. VitalSeker ne remplace pas un professionnel de
/// santé qualifié.'"
///
/// This widget should be placed at the bottom of every screen that displays
/// triage results, AI insights, vital-sign interpretations, medication lists,
/// medical records, or any other clinically meaningful content.
///
/// Usage:
///   Column(children: [..., const MedicalDisclaimerBanner()])
class MedicalDisclaimerBanner extends StatelessWidget {
  /// Optional compact mode — uses smaller padding and font for inline use.
  final bool compact;

  const MedicalDisclaimerBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.warning(isDark).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(
          color: AppColors.warning(isDark).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: compact ? 14 : 18,
            color: AppColors.warning(isDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.medicalDisclaimer,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
