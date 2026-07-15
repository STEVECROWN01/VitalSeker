import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Seker AI Info Screen — shows when the user taps the Seker avatar.
/// Displays the AI's profile picture, name, description, capabilities,
/// and safety warnings.
///
/// FIX (audit M-1): all strings are now localized via AppLocalizations.
class SekerInfoScreen extends StatelessWidget {
  const SekerInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

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
        title: Text(l10n.aboutSekerAi, style: AppTextStyles.heading3),
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
                errorBuilder: (context, error, stack) => SizedBox(
                  width: 120,
                  height: 120,
                  child: Icon(Icons.smart_toy, size: 60, color: AppColors.primary(isDark)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.sekerAiName,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sekerAiSubtitle,
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
              title: l10n.sekerWhatIsTitle,
              body: l10n.sekerWhatIsBody,
            ),
            const SizedBox(height: 16),

            // What can Seker do?
            _InfoCard(
              isDark: isDark,
              icon: Icons.psychology_outlined,
              title: l10n.sekerCapabilitiesTitle,
              body: l10n.sekerCapabilitiesBody,
            ),
            const SizedBox(height: 16),

            // How to use
            _InfoCard(
              isDark: isDark,
              icon: Icons.chat_outlined,
              title: l10n.sekerHowToUseTitle,
              body: l10n.sekerHowToUseBody,
            ),
            const SizedBox(height: 16),

            // Safety warnings
            _InfoCard(
              isDark: isDark,
              icon: Icons.warning_amber_rounded,
              title: l10n.sekerSafetyTitle,
              body: l10n.sekerSafetyBody,
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
                  l10n.backToChat,
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                    ),
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
