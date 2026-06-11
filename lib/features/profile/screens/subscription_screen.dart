import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_colors.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
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
              isCurrentPlan: subAsync.maybeWhen(
                data: (s) => s?.isFree ?? true,
                orElse: () => true,
              ),
              isDark: isDark,
              onTap: () {},
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
              isCurrentPlan: subAsync.maybeWhen(
                data: (s) => s?.isPro ?? false,
                orElse: () => false,
              ),
              isRecommended: true,
              isDark: isDark,
              onTap: () {
                // TODO: RevenueCat integration
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment integration coming soon!')),
                );
              },
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
              isCurrentPlan: subAsync.maybeWhen(
                data: (s) => s?.isEnterprise ?? false,
                orElse: () => false,
              ),
              isDark: isDark,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact us for enterprise plans')),
                );
              },
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                'Powered by ${AppConfig.producer}',
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
  final bool isRecommended;
  final bool isDark;
  final VoidCallback onTap;

  const _PlanCard({
    required this.planName,
    required this.price,
    required this.period,
    required this.features,
    required this.isCurrentPlan,
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
                    ? OutlinedButton(
                        onPressed: null,
                        child: const Text('Current Plan'),
                      )
                    : ElevatedButton(
                        onPressed: onTap,
                        style: isRecommended
                            ? ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(isDark),
                              )
                            : null,
                        child: Text(planName == 'Free' ? 'Downgrade' : 'Upgrade to $planName'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
