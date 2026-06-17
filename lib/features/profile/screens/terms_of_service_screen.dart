import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

/// Terms of Service screen.
///
/// Static legal copy. The "Last updated" date is derived from the app version
/// so it stays in sync with releases without manual edits.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary(isDark).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary(isDark).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppColors.primary(isDark),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppConfig.appName} Terms of Service',
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last updated: Version ${AppConfig.version}',
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
            ),
            const SizedBox(height: 24),

            _Section(
              number: '1',
              title: 'Acceptance of Terms',
              isDark: isDark,
              children: [
                _Para(
                  'By creating an account, accessing, or using the ${AppConfig.appName} '
                  'mobile application ("the Service"), you agree to be bound by these '
                  'Terms of Service ("Terms"). If you do not agree to these Terms, you '
                  'must not access or use the Service.',
                  isDark: isDark,
                ),
                _Para(
                  'The Service is provided by ${AppConfig.producer} ("we", "us", or "our"). '
                  'These Terms form a legally binding agreement between you and us.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '2',
              title: 'Eligibility & Account',
              isDark: isDark,
              children: [
                _Para(
                  'You must be at least 13 years old to use the Service. If you are under '
                  '18, you represent that your parent or legal guardian has read and '
                  'agreed to these Terms on your behalf.',
                  isDark: isDark,
                ),
                _Para(
                  'You are responsible for maintaining the confidentiality of your account '
                  'credentials and for all activities that occur under your account. '
                  'Notify us immediately of any unauthorized use of your account.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '3',
              title: 'Health Information — Not Medical Advice',
              isDark: isDark,
              children: [
                _Para(
                  '${AppConfig.appName} is a health companion application intended for '
                  'informational and organizational purposes only. The Service is NOT a '
                  'medical device and does not provide medical advice, diagnosis, or '
                  'treatment recommendations.',
                  isDark: isDark,
                ),
                _Para(
                  'The AI triage feature provides general guidance based on the symptoms '
                  'you report. It is not a substitute for professional medical judgment. '
                  'Always seek the advice of a qualified healthcare provider with any '
                  'questions you may have regarding a medical condition. Never disregard '
                  'professional medical advice or delay seeking it because of something '
                  'you read in this Service.',
                  isDark: isDark,
                ),
                _Para(
                  'In a medical emergency, call your local emergency number (e.g. 911, 112) '
                  'immediately. Do not rely on the Service for emergency response.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '4',
              title: 'Use of the Service',
              isDark: isDark,
              children: [
                _Para('You agree NOT to:', isDark: isDark, bold: true),
                _Bullet('Use the Service for any unlawful purpose;', isDark: isDark),
                _Bullet('Attempt to reverse-engineer, decompile, or disassemble the app;', isDark: isDark),
                _Bullet('Upload content that is malicious, fraudulent, or violates intellectual property rights;', isDark: isDark),
                _Bullet('Interfere with the proper functioning of the Service or attempt to access data belonging to other users;', isDark: isDark),
                _Bullet('Use the Service to send unsolicited communications or spam.', isDark: isDark),
              ],
            ),

            _Section(
              number: '5',
              title: 'Subscriptions & Payments',
              isDark: isDark,
              children: [
                _Para(
                  'Certain features of the Service require a paid subscription ("Pro" or '
                  '"Enterprise" plan). Subscription fees are billed monthly through the '
                  'platform application store (Apple App Store or Google Play Store) '
                  'subject to their respective terms.',
                  isDark: isDark,
                ),
                _Para(
                  'Subscriptions automatically renew unless cancelled at least 24 hours '
                  'before the end of the current billing period. You can manage or cancel '
                  'your subscription at any time through your platform\'s account settings.',
                  isDark: isDark,
                ),
                _Para(
                  'We may change subscription fees upon reasonable notice. Fee changes '
                  'will not apply to your current billing period.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '6',
              title: 'Your Data',
              isDark: isDark,
              children: [
                _Para(
                  'You retain ownership of the health data you submit to the Service. '
                  'Our use of your data is described in our Privacy Policy, which is '
                  'incorporated into these Terms by reference.',
                  isDark: isDark,
                ),
                _Para(
                  'You may export your data at any time via the in-app Export feature, '
                  'and you may permanently delete your account and all associated data '
                  'via Settings → Delete Account.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '7',
              title: 'Disclaimers',
              isDark: isDark,
              children: [
                _Para(
                  'THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT '
                  'WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT '
                  'LIMITED TO IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A '
                  'PARTICULAR PURPOSE, OR NON-INFRINGEMENT.',
                  isDark: isDark,
                ),
                _Para(
                  'We do not warrant that the Service will be uninterrupted, error-free, '
                  'or secure, or that the AI triage recommendations will be accurate or '
                  'appropriate for your specific situation.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '8',
              title: 'Limitation of Liability',
              isDark: isDark,
              children: [
                _Para(
                  'TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT SHALL '
                  '${AppConfig.producer.toUpperCase()} BE LIABLE FOR ANY INDIRECT, '
                  'INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS '
                  'OF DATA, ARISING OUT OF OR RELATED TO YOUR USE OF (OR INABILITY TO '
                  'USE) THE SERVICE, WHETHER BASED ON WARRANTY, CONTRACT, TORT, OR ANY '
                  'OTHER LEGAL THEORY.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '9',
              title: 'Termination',
              isDark: isDark,
              children: [
                _Para(
                  'You may stop using the Service and delete your account at any time via '
                  'Settings. We may suspend or terminate your access to the Service if you '
                  'violate these Terms or if we reasonably believe we are required to do '
                  'so by law.',
                  isDark: isDark,
                ),
                _Para(
                  'Upon termination, all licenses granted to you will end, and your data '
                  'will be deleted in accordance with our Privacy Policy.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '10',
              title: 'Changes to These Terms',
              isDark: isDark,
              children: [
                _Para(
                  'We may update these Terms from time to time. We will notify you of '
                  'material changes via the app or by email. Continued use of the Service '
                  'after changes take effect constitutes acceptance of the revised Terms.',
                  isDark: isDark,
                ),
              ],
            ),

            _Section(
              number: '11',
              title: 'Contact',
              isDark: isDark,
              children: [
                _Para(
                  'Questions about these Terms? Contact us at support@vitalseker.com.',
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: AppColors.divider(isDark)),
            const SizedBox(height: 12),
            Text(
              '© ${DateTime.now().year} ${AppConfig.producer}. All rights reserved. '
              'Version ${AppConfig.version}.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textHint(isDark),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String number;
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _Section({
    required this.number,
    required this.title,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Para extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool bold;

  const _Para(this.text, {required this.isDark, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.6,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: AppColors.textSecondary(isDark),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final bool isDark;

  const _Bullet(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.6,
              color: AppColors.primary(isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.6,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
