import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

/// Reusable Pro-feature gate screen.
/// Shows when a free user tries to access a Pro-only feature.
/// Displays the feature name, a message, and two buttons:
/// - "Subscribe to Pro" → goes to subscription screen
/// - "View All Plans" → goes to subscription screen
class ProFeatureGate extends StatelessWidget {
  final String featureName;
  final String? featureDescription;
  final IconData featureIcon;

  const ProFeatureGate({
    super.key,
    required this.featureName,
    this.featureDescription,
    this.featureIcon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

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
        title: Text(featureName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer(isDark),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  featureIcon,
                  size: 40,
                  color: AppColors.primary(isDark),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                featureName,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                featureDescription ??
                    'This feature is only available on the VitalSeker Pro plan. Upgrade to unlock $featureName and more premium features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary(isDark),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go(AppConfig.proPlan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(isDark),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    // FIX (audit L-11): use AppConfig.proPriceMonthly
                    // instead of hardcoded $6.99.
                    'Subscribe to Pro — \$${AppConfig.proPriceMonthly}/month',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go(AppConfig.subscription),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary(isDark),
                    side: BorderSide(color: AppColors.primary(isDark)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.viewAllPlans,
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
      ),
    );
  }
}
