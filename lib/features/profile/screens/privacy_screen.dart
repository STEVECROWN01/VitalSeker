import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.shield_outlined, color: AppColors.primary(isDark), size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.privacyPolicyTitle,
                    style: const TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.privacyLastUpdated,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Intro
            _PolicyText(
              l10n.privacyIntro(AppConfig.appName),
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Data Collection
            _SectionHeading(title: l10n.privacySectionDataCollection, isDark: isDark),
            _PolicyText(
              l10n.privacyDataCollectionBody,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Data Storage & Encryption
            _SectionHeading(title: l10n.privacySectionDataStorage, isDark: isDark),
            _PolicyText(
              l10n.privacyDataStorageBody,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // GDPR Compliance
            _SectionHeading(title: l10n.privacySectionGdpr, isDark: isDark),
            _PolicyText(
              l10n.privacyGdprBody(AppConfig.appName),
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Your Rights
            _SectionHeading(title: l10n.privacySectionYourRights, isDark: isDark),
            _PolicyText(
              l10n.privacyRightsBody,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Contact Us
            _SectionHeading(title: l10n.privacySectionContactUs, isDark: isDark),
            _PolicyText(
              l10n.privacyContactBody(AppConfig.producer),
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Footer
            Center(
              child: Column(
                children: [
                  Text(
                    l10n.privacyCopyright(AppConfig.producer),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppConfig.appName} v${AppConfig.version}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isDark ? AppColors.grey600 : AppColors.grey300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeading({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'ClashDisplay',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(isDark),
        ),
      ),
    );
  }
}

class _PolicyText extends StatelessWidget {
  final String text;
  final bool isDark;

  const _PolicyText(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: isDark ? AppColors.grey300 : AppColors.grey700,
        height: 1.7,
      ),
    );
  }
}
