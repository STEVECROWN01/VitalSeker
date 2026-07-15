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

            // FIX (audit M-15): add missing sections for legal compliance.
            // Third-Party Processors
            _SectionHeading(title: '6. Third-Party Processors', isDark: isDark),
            _PolicyText(
              'We use the following third-party services to provide VitalSeker. Each '
              'processor has signed a Data Processing Agreement and complies with GDPR:\n\n'
              '• Supabase (database, auth, file storage) — EU/US data centers\n'
              '• Sentry (crash monitoring) — anonymized error data only\n'
              '• PostHog (analytics) — anonymized usage events\n'
              '• OneSignal (push notifications) — device tokens only\n'
              '• RevenueCat (subscription management) — purchase receipts\n'
              '• Twilio (SMS for SOS alerts) — phone numbers and SMS content\n'
              '• z.ai / GLM-4 (AI triage and chat) — symptom text and health context\n'
              '• DeepL (translation) — text snippets for translation\n'
              '• Google Sign-In / Apple Sign-In — OAuth tokens only\n\n'
              'We do NOT share your health data with advertising networks, data brokers, '
              'or insurance companies.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Data Retention
            _SectionHeading(title: '7. Data Retention', isDark: isDark),
            _PolicyText(
              'We retain your data for the following periods:\n\n'
              '• Health data (vitals, symptom logs, triage results): 24 months after '
              'your last activity, then automatically deleted.\n'
              '• Account data (profile, passport): retained until you delete your account.\n'
              '• SOS event records: 12 months for audit and safety purposes.\n'
              '• Support tickets: 6 months after resolution.\n'
              '• Crash/analytics data: 90 days (anonymized).\n\n'
              'You can request earlier deletion at any time via Settings > Delete Account. '
              'Note: some data (e.g., financial records for RevenueCat) may be retained '
              'longer for legal compliance.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Children's Privacy
            _SectionHeading(title: "8. Children's Privacy", isDark: isDark),
            _PolicyText(
              'VitalSeker is not intended for use by children under 13 (under 16 in the EU). '
              'We do not knowingly collect data from children. If you believe a child has '
              'provided personal information, contact us immediately at privacy@vitalseker.com '
              'and we will delete it.\n\nFor users aged 13-17 (or 16-17 in the EU), parental '
              'consent is required. VitalSeker does not currently implement age verification — '
              'this must be added before targeting users under 18.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Medical Disclaimer
            _SectionHeading(title: '9. Medical Disclaimer', isDark: isDark),
            _PolicyText(
              'VitalSeker is a health companion app, NOT a medical device. It is not '
              'certified by the FDA, EMA, or any other regulatory body. The AI triage '
              'feature provides general guidance only — it does NOT constitute a medical '
              'diagnosis. Always consult a qualified healthcare professional for diagnosis '
              'and treatment.\n\nVitalSeker does not replace emergency services. In a '
              'life-threatening emergency, call your local emergency number (112, 911, 15) '
              'directly — do not rely solely on the app.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Changes to This Policy
            _SectionHeading(title: '10. Changes to This Policy', isDark: isDark),
            _PolicyText(
              'We may update this Privacy Policy from time to time. When we do, we will '
              'notify you through the app and update the "Last updated" date. If material '
              'changes are made, we will require your renewed consent before continuing '
              'to process your data under the new terms.',
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
