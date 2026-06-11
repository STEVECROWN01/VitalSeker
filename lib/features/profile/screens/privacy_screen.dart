import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
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
                      color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.shield_outlined, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Last updated: March 2025',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Intro
            _PolicyText(
              'At ${AppConfig.appName}, your privacy is paramount. This Privacy Policy explains how we collect, use, store, and protect your personal and health-related data. By using our services, you agree to the practices described below.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Data Collection
            _SectionHeading(title: '1. Data Collection', isDark: isDark),
            _PolicyText(
              'We collect the following categories of data:\n\n'
              '• Personal Information: Name, email address, phone number, date of birth, and gender.\n'
              '• Health Data: Blood type, allergies, chronic conditions, medications, vital signs, symptom logs, and triage results.\n'
              '• Emergency Contacts: Names, phone numbers, and relationships of your designated contacts.\n'
              '• Device Data: Device type, operating system, and app version for compatibility and support.\n'
              '• Usage Data: Feature interactions and anonymized analytics to improve our services.\n\n'
              'We only collect data that is necessary for providing our health companion services. You have full control over what information you provide.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Data Storage & Encryption
            _SectionHeading(title: '2. Data Storage & Encryption', isDark: isDark),
            _PolicyText(
              'Your data is stored using industry-leading security measures:\n\n'
              '• Encryption at Rest: All data stored in our databases is encrypted using AES-256 encryption.\n'
              '• Encryption in Transit: All data transmitted between your device and our servers uses TLS 1.3 encryption.\n'
              '• Health Passport: Your health passport data is encrypted with a unique key derived from your credentials.\n'
              '• QR Code Sharing: Shared health data via QR codes is encrypted and time-limited.\n'
              '• Infrastructure: Our servers are hosted in SOC 2 Type II certified data centers with 24/7 monitoring.\n\n'
              'We do not store payment card information. All payment processing is handled by certified third-party providers.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // GDPR Compliance
            _SectionHeading(title: '3. GDPR Compliance', isDark: isDark),
            _PolicyText(
              '${AppConfig.appName} is fully compliant with the General Data Protection Regulation (GDPR):\n\n'
              '• Lawful Basis: We process your data based on your explicit consent and contractual necessity.\n'
              '• Data Minimization: We only collect and process data that is strictly necessary.\n'
              '• Purpose Limitation: Your data is used only for the purposes for which it was collected.\n'
              '• Right to Access: You can request a complete copy of your personal data at any time.\n'
              '• Right to Rectification: You can update or correct your data through the app settings.\n'
              '• Right to Erasure: You can request complete deletion of your account and data.\n'
              '• Right to Portability: You can export your data in a machine-readable format.\n'
              '• Data Processing Agreements: All third-party processors have signed DPAs.\n'
              '• Cross-Border Transfers: Data is processed within the EU/EEA unless explicit consent is given otherwise.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Your Rights
            _SectionHeading(title: '4. Your Rights', isDark: isDark),
            _PolicyText(
              'You have the following rights regarding your data:\n\n'
              '• Access: View all your personal and health data within the app or request a data export.\n'
              '• Correction: Edit your profile information at any time through Edit Profile.\n'
              '• Deletion: Request account deletion through Settings > Data & Privacy > Delete Account.\n'
              '• Restriction: Limit how certain data is processed by adjusting your notification and sharing preferences.\n'
              '• Objection: Object to specific data processing activities by contacting our Data Protection Officer.\n'
              '• Withdrawal of Consent: You may withdraw consent at any time without affecting the lawfulness of prior processing.\n\n'
              'To exercise any of these rights, contact us at privacy@vitalseker.com or through the in-app support feature.',
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Contact Us
            _SectionHeading(title: '5. Contact Us', isDark: isDark),
            _PolicyText(
              'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us:\n\n'
              '• Email: privacy@vitalseker.com\n'
              '• Support: support@vitalseker.com\n'
              '• Data Protection Officer: dpo@vitalseker.com\n'
              '• Address: ${AppConfig.producer}, Data Protection Office\n\n'
              'We aim to respond to all privacy-related inquiries within 30 days.',
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Footer
            Center(
              child: Column(
                children: [
                  Text(
                    '© 2025 ${AppConfig.producer}. All rights reserved.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
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
          color: isDark ? Colors.white : AppColors.lightOnBackground,
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
