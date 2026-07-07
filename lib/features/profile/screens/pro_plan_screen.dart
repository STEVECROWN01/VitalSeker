import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// Single Pro Plan presentation screen.
/// Shows only the Pro plan with its features and a subscribe button.
class ProPlanScreen extends ConsumerStatefulWidget {
  const ProPlanScreen({super.key});

  @override
  ConsumerState<ProPlanScreen> createState() => _ProPlanScreenState();
}

class _ProPlanScreenState extends ConsumerState<ProPlanScreen> {
  bool _isSubscribing = false;

  Future<void> _subscribe() async {
    setState(() => _isSubscribing = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final db = ref.read(databaseServiceProvider);
      final existing = await db.getSubscription(user.id);

      final now = DateTime.now();
      final periodEnd = now.add(const Duration(days: 30));

      if (existing == null) {
        await db.createSubscription({
          'user_id': user.id,
          'plan': 'pro',
          'status': 'active',
          'current_period_start': now.toIso8601String(),
          'current_period_end': periodEnd.toIso8601String(),
          'cancel_at_period_end': false,
        });
      } else {
        await db.updateSubscription(existing.id, {
          'plan': 'pro',
          'status': 'active',
          'current_period_start': now.toIso8601String(),
          'current_period_end': periodEnd.toIso8601String(),
          'cancel_at_period_end': false,
        });
      }

      ref.invalidate(subscriptionProvider);
      ref.invalidate(userProfileProvider);

      if (mounted) {
        AppSnackBar.success(context, 'Welcome to VitalSeker Pro!');
        context.go(AppConfig.dashboard);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not subscribe. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppConfig.dashboard);
            }
          },
        ),
        title: Text('VitalSeker Pro', style: AppTextStyles.heading3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Plan icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradientFor(isDark),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'VitalSeker Pro',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$6.99/month',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary(isDark),
              ),
            ),
            const SizedBox(height: 32),
            // Features list
            _FeatureItem(icon: Icons.chat, text: 'AI Chat with Seker — real-time health guidance', isDark: isDark),
            _FeatureItem(icon: Icons.healing, text: 'AI Triage — 5-step symptom analysis with results', isDark: isDark),
            _FeatureItem(icon: Icons.qr_code_2, text: 'QR Code Sharing — encrypted health passport', isDark: isDark),
            _FeatureItem(icon: Icons.emergency, text: 'Emergency SOS — instant alerts to contacts', isDark: isDark),
            _FeatureItem(icon: Icons.translate, text: 'Medical Translation — 40+ languages with OCR', isDark: isDark),
            _FeatureItem(icon: Icons.folder_outlined, text: 'Medical Records — scan, store, manage documents', isDark: isDark),
            _FeatureItem(icon: Icons.picture_as_pdf, text: 'PDF Export — comprehensive health reports', isDark: isDark),
            _FeatureItem(icon: Icons.family_restroom, text: 'Family Profiles — up to 5 family members', isDark: isDark),
            _FeatureItem(icon: Icons.insights, text: 'Weekly AI Insights — personalized health summaries', isDark: isDark),
            const SizedBox(height: 32),
            // Subscribe button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubscribing ? null : _subscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(isDark),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubscribing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Subscribe to Pro — \$6.99/month',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // View all plans
            TextButton(
              onPressed: () => context.go(AppConfig.subscription),
              child: Text(
                'View All Plans',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _FeatureItem({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary(isDark), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
