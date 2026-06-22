import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo & Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConfig.appName,
                    style: const TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    AppConfig.appTagline,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.aboutVitalSekerVersion(AppConfig.version),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // About
            _SectionCard(
              title: l10n.aboutVitalSeker,
              icon: Icons.info_outline,
              isDark: isDark,
              children: [
                Text(
                  l10n.aboutVitalSekerBody,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: isDark ? AppColors.grey300 : AppColors.grey700,
                    height: 1.7,
                  ),
                ),
              ],
            ),

            // Features
            _SectionCard(
              title: l10n.keyFeatures,
              icon: Icons.star_outline,
              isDark: isDark,
              children: [
                _FeatureItem(icon: Icons.psychology, title: l10n.featureAiTriageTitle, description: l10n.featureAiTriageDesc, isDark: isDark),
                _FeatureItem(icon: Icons.badge, title: l10n.featureHealthPassportTitle, description: l10n.featureHealthPassportDesc, isDark: isDark),
                _FeatureItem(icon: Icons.qr_code_2, title: l10n.featureQrSharingTitle, description: l10n.featureQrSharingDesc, isDark: isDark),
                _FeatureItem(icon: Icons.emergency, title: l10n.featureEmergencySosTitle, description: l10n.featureEmergencySosDesc, isDark: isDark),
                _FeatureItem(icon: Icons.insights, title: l10n.featureWeeklyInsightsTitle, description: l10n.featureWeeklyInsightsDesc, isDark: isDark),
                _FeatureItem(icon: Icons.family_restroom, title: l10n.featureFamilyProfilesTitle, description: l10n.featureFamilyProfilesDesc, isDark: isDark),
                _FeatureItem(icon: Icons.picture_as_pdf, title: l10n.featurePdfExportTitle, description: l10n.featurePdfExportDesc, isDark: isDark),
              ],
            ),

            // Keter Marketing Credit
            _SectionCard(
              title: l10n.producer,
              icon: Icons.business,
              isDark: isDark,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.rocket_launch, color: Colors.white, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        AppConfig.producer,
                        style: const TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.conceptDesignDevelopment,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Legal
            _SectionCard(
              title: l10n.legal,
              icon: Icons.gavel,
              isDark: isDark,
              children: [
                ListTile(
                  title: Text(l10n.privacyPolicy, style: const TextStyle(fontFamily: 'Inter')),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () => context.push(AppConfig.privacyPolicy),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  title: Text(l10n.termsOfService, style: const TextStyle(fontFamily: 'Inter')),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () => context.push(AppConfig.termsOfService),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                l10n.poweredByProducer(AppConfig.producer),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textHint(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary(isDark)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  const _FeatureItem({required this.icon, required this.title, required this.description, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary(isDark), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
