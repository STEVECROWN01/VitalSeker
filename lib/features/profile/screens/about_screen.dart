import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
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
                  const Text(
                    AppConfig.appName,
                    style: TextStyle(
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
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version ${AppConfig.version}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // About
            _SectionCard(
              title: 'About VitalSeker',
              icon: Icons.info_outline,
              children: [
                Text(
                  'VitalSeker is your AI-powered health companion that puts you in control of your health journey. With intelligent symptom triage, a secure health passport, emergency SOS alerts, and personalized weekly insights, VitalSeker ensures you always have the information you need when it matters most. Built with cutting-edge AI technology and bank-grade security, your health data stays private and protected.',
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
              title: 'Key Features',
              icon: Icons.star_outline,
              children: [
                _FeatureItem(icon: Icons.psychology, title: 'AI Symptom Triage', description: 'Get instant AI-powered health recommendations'),
                _FeatureItem(icon: Icons.badge, title: 'Health Passport', description: 'Carry your encrypted health profile everywhere'),
                _FeatureItem(icon: Icons.qr_code_2, title: 'QR Code Sharing', description: 'Share health info securely with any provider'),
                _FeatureItem(icon: Icons.emergency, title: 'Emergency SOS', description: 'One-tap alerts with GPS location sharing'),
                _FeatureItem(icon: Icons.insights, title: 'Weekly Insights', description: 'AI-generated health summaries (Pro)'),
                _FeatureItem(icon: Icons.family_restroom, title: 'Family Profiles', description: 'Manage health for your entire family'),
                _FeatureItem(icon: Icons.picture_as_pdf, title: 'PDF Export', description: 'Generate and share health reports'),
              ],
            ),

            // Keter Marketing Credit
            _SectionCard(
              title: 'Producer',
              icon: Icons.business,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        AppConfig.producer,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Concept, Design & Development',
                        style: TextStyle(
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
              title: 'Legal',
              icon: Icons.gavel,
              children: [
                ListTile(
                  title: const Text('Privacy Policy', style: TextStyle(fontFamily: 'Inter')),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {},
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  title: const Text('Terms of Service', style: TextStyle(fontFamily: 'Inter')),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {},
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Made with care by ${AppConfig.producer}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark ? AppColors.grey500 : AppColors.grey400,
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
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.lightPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightOnBackground,
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

  const _FeatureItem({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.lightPrimary, size: 18),
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
                    color: isDark ? AppColors.grey400 : AppColors.grey500,
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
