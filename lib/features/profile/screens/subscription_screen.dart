import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _pendingPlan;
  bool _isRestoring = false;

  /// Apply a plan change. In production this would launch the platform
  /// paywall (RevenueCat / StoreKit / Google Play Billing) and only update
  /// the DB row after a successful purchase callback. For now, we update the
  /// subscription row directly so the rest of the app sees the new tier —
  /// this is clearly disclosed to the user via the dev-mode banner.
  Future<void> _changePlan(String planName) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.error(context, 'You must be signed in to change plans.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Switch to $planName?'),
        content: Text(
          planName == 'free'
              ? 'You will lose access to Pro features at the end of your current billing period. Continue?'
              : 'This will update your subscription to $planName. In production this would launch the platform paywall; for now the change is applied directly to your account for testing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _pendingPlan = planName);
    try {
      final db = ref.read(databaseServiceProvider);
      final existing = await db.getSubscription(user.id);

      final now = DateTime.now();
      final periodEnd = DateTime(now.year, now.month + 1, now.day);

      if (existing == null) {
        await db.createSubscription({
          'user_id': user.id,
          'plan': planName,
          'status': planName == 'free' ? 'active' : 'active',
          'current_period_start': now.toIso8601String(),
          'current_period_end': periodEnd.toIso8601String(),
          'cancel_at_period_end': false,
        });
      } else {
        await db.updateSubscription(existing.id, {
          'plan': planName,
          'status': 'active',
          'current_period_start': now.toIso8601String(),
          'current_period_end': periodEnd.toIso8601String(),
          'cancel_at_period_end': false,
        });
      }

      ref.invalidate(subscriptionProvider);
      ref.invalidate(userProfileProvider);
      if (mounted) {
        AppSnackBar.success(
          context,
          planName == 'free'
              ? 'Downgraded to Free. Pro access ends at the next billing period.'
              : 'Welcome to $planName! All features unlocked.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(context, 'Failed to update subscription. Please try again.', e);
      }
    } finally {
      if (mounted) setState(() => _pendingPlan = null);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    try {
      // In production: query RevenueCat / StoreKit for existing purchases.
      // For now, just refresh the subscription from the DB.
      ref.invalidate(subscriptionProvider);
      await ref.read(subscriptionProvider.future);
      if (mounted) {
        AppSnackBar.success(context, 'Purchases restored.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(context, 'Failed to restore purchases.', e);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subAsync = ref.watch(subscriptionProvider);
    final currentPlan = subAsync.maybeWhen(
      data: (s) => s?.plan ?? 'free',
      orElse: () => 'free',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          TextButton.icon(
            onPressed: _isRestoring ? null : _restorePurchases,
            icon: _isRestoring
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore, size: 18),
            label: const Text('Restore'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.workspace_premium, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Choose Your Plan',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Unlock the full power of VitalSeker',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dev-mode disclosure banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.construction_outlined,
                    size: 18,
                    color: isDark ? AppColors.darkWarning : AppColors.lightWarning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In-app payment integration (RevenueCat / StoreKit) is pending. Plan changes are applied directly to your account for testing.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondary(isDark),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Free Plan
            _PlanCard(
              planName: 'Free',
              price: '\$0',
              period: 'forever',
              features: [
                '3 AI triage sessions/month',
                'Basic health passport',
                'QR code sharing',
                'Emergency SOS alerts',
                'Single user profile',
              ],
              isCurrentPlan: currentPlan == 'free',
              isLoading: _pendingPlan == 'free',
              isDark: isDark,
              onTap: () => _changePlan('free'),
            ),
            const SizedBox(height: 16),

            // Pro Plan
            _PlanCard(
              planName: 'Pro',
              price: '\$${AppConfig.proPriceMonthly.toStringAsFixed(2)}',
              period: '/month',
              features: [
                'Unlimited AI triage sessions',
                'Advanced health passport',
                'Weekly AI insights',
                'Family profiles (up to 5)',
                'PDF export with full history',
                'Priority support',
              ],
              isCurrentPlan: currentPlan == 'pro',
              isLoading: _pendingPlan == 'pro',
              isRecommended: true,
              isDark: isDark,
              onTap: () => _changePlan('pro'),
            ),
            const SizedBox(height: 16),

            // Enterprise Plan
            _PlanCard(
              planName: 'Enterprise',
              price: '\$${AppConfig.enterprisePriceMonthly.toStringAsFixed(0)}',
              period: '/month',
              features: [
                'Everything in Pro',
                'Unlimited family profiles',
                'Custom branding',
                'API access',
                'Dedicated support',
                'SLA guarantee',
              ],
              isCurrentPlan: currentPlan == 'enterprise',
              isLoading: _pendingPlan == 'enterprise',
              isDark: isDark,
              onTap: () => _changePlan('enterprise'),
            ),

            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('mailto:sales@vitalseker.com?subject=VitalSeker%20Enterprise%20Inquiry');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (mounted) {
                      AppSnackBar.info(context, 'Email sales@vitalseker.com for enterprise pricing.');
                    }
                  }
                },
                icon: const Icon(Icons.alternate_email, size: 16),
                label: const Text('Contact sales for custom Enterprise terms'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Crafted under ${AppConfig.producer} design guidance.',
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

class _PlanCard extends StatelessWidget {
  final String planName;
  final String price;
  final String period;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isLoading;
  final bool isRecommended;
  final bool isDark;
  final VoidCallback onTap;

  const _PlanCard({
    required this.planName,
    required this.price,
    required this.period,
    required this.features,
    required this.isCurrentPlan,
    this.isLoading = false,
    this.isRecommended = false,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isRecommended
            ? Border.all(color: AppColors.primary(isDark), width: 2)
            : null,
      ),
      child: Card(
        shape: isRecommended
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        planName,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary(isDark),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        TextSpan(
                          text: period,
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
              const SizedBox(height: 16),
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.primary(isDark)),
                    const SizedBox(width: 8),
                    Text(
                      f,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark ? AppColors.grey300 : AppColors.grey700,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: isCurrentPlan
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Current Plan'),
                      )
                    : ElevatedButton(
                        onPressed: isLoading ? null : onTap,
                        style: isRecommended
                            ? ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(isDark),
                              )
                            : null,
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(planName == 'Free' ? 'Downgrade' : 'Upgrade to $planName'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
