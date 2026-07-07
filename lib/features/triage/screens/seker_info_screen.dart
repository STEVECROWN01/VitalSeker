import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Seker AI Info Screen — shows when the user taps the Seker avatar.
/// Displays the AI's profile picture, name, description, capabilities,
/// and safety warnings.
class SekerInfoScreen extends StatelessWidget {
  const SekerInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppConfig.aiChat);
            }
          },
        ),
        title: Text('About Seker AI', style: AppTextStyles.heading3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Seker AI avatar — large
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.asset(
                'assets/images/branding/seker_ai_avatar.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Seker AI',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your AI Health Assistant',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 32),

            // What is Seker?
            _InfoCard(
              isDark: isDark,
              icon: Icons.info_outline,
              title: 'What is Seker?',
              body: 'Seker is an AI-powered health assistant built into VitalSeker. '
                  'Seker is an expert in biology, human health, psychology, and the human body. '
                  'Seker provides general health guidance, symptom analysis, and emotional support.',
            ),
            const SizedBox(height: 16),

            // What can Seker do?
            _InfoCard(
              isDark: isDark,
              icon: Icons.psychology_outlined,
              title: 'What can Seker do?',
              body: '• Understand your symptoms and ask follow-up questions\n'
                  '• Provide general health guidance and coaching\n'
                  '• Help manage stress, anxiety, and emotional well-being\n'
                  '• Auto-detect and save health information you share\n'
                  '• Respond in your language (40+ supported)\n'
                  '• Accept voice notes and file uploads',
            ),
            const SizedBox(height: 16),

            // How to use
            _InfoCard(
              isDark: isDark,
              icon: Icons.chat_outlined,
              title: 'How to use Seker',
              body: '1. Type your message or tap the mic to speak\n'
                  '2. Seker will ask questions to understand your situation\n'
                  '3. Seker provides guidance and recommendations\n'
                  '4. You can upload prescriptions, lab results, or images\n'
                  '5. Health information you share is auto-saved to your profile',
            ),
            const SizedBox(height: 16),

            // Safety warnings
            _InfoCard(
              isDark: isDark,
              icon: Icons.warning_amber_rounded,
              title: 'Important Safety Information',
              body: '• Seker provides general guidance, NOT a medical diagnosis\n'
                  '• Always consult a professional doctor for proper diagnosis\n'
                  '• Seker does NOT recommend specific medications or dosages\n'
                  '• For emergencies, call 112 or 911 immediately\n'
                  '• Seker only discusses health, biology, and psychology\n'
                  '• Your conversations are private and secure',
              iconColor: AppColors.warning(isDark),
            ),
            const SizedBox(height: 32),

            // Back to chat button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    context.go(AppConfig.aiChat);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(isDark),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Back to Chat',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String body;
  final Color? iconColor;

  const _InfoCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.body,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor ?? AppColors.primary(isDark), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.6,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
