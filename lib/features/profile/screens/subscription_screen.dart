import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/revenuecat_service.dart';
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

  /// Apply a plan change.
  ///
  /// SECURITY (audit C-7, C-8 fix): paid plans (pro, enterprise) MUST go
  /// through RevenueCat. If RevenueCat is not configured, we FAIL CLOSED —
  /// the user sees an error and no DB write happens. The previous
  /// implementation fell through to a direct DB write that granted the
  /// requested plan without payment, which was a payment bypass.
  ///
  /// Only the 'free' plan can be set without payment (it's a downgrade).
  /// Even then, the DB row is only written by the client to mirror what
  /// the RevenueCat webhook will eventually write — the server-side
  /// webhook (service-role) is the source of truth.
  Future<void> _changePlan(String planName) async {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.error(context, l10n.mustBeSignedInToChangePlans);
      return;
    }

    // CRITICAL: For paid plans, require RevenueCat in production. In debug
    // mode, allow direct DB write for testing without RevenueCat configured.
    //
    // We gate on `hasRealApiKey` (not `isConfigured`) because Purchases.configure()
    // can succeed even with a bogus/placeholder key — leaving isConfigured=true
    // while getOfferings() returns null. That combination previously defeated
    // the debug bypass and surfaced a misleading "Could not load plans" error.
    // `hasRealApiKey` is true ONLY when a non-placeholder key was supplied.
    final rcService = RevenueCatService();
    final isPaidPlan = planName == 'pro' || planName == 'enterprise';

    if (isPaidPlan && !rcService.hasRealApiKey && !kDebugMode) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'In-app purchases are not available on this device. '
          'Please update the app or contact support.',
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.switchToPlan(planName)),
        content: Text(
          planName == 'free'
              ? l10n.downgradeToFreeMessage
              : l10n.upgradeToPlanMessage(planName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _pendingPlan = planName);
    try {
      // In debug mode without a real RevenueCat API key, skip IAP and write
      // directly to DB. This is the dev-mode bypass.
      if (isPaidPlan && !rcService.hasRealApiKey && kDebugMode) {
        try {
          final db = ref.read(databaseServiceProvider);
          final existing = await db.getSubscription(user.id);
          final now = DateTime.now();
          final periodEnd = now.add(const Duration(days: 30));
          final payload = {
            'plan': planName,
            'status': 'active',
            'current_period_start': now.toIso8601String(),
            'current_period_end': periodEnd.toIso8601String(),
            'cancel_at_period_end': false,
          };
          if (existing == null) {
            await db.createSubscription({'user_id': user.id, ...payload});
          } else {
            await db.updateSubscription(existing.id, payload);
          }
        } catch (e) {
          debugPrint('[Subscription] dev-mode DB write failed (RLS hardened? '
              'non-fatal): $e');
        }
        ref.invalidate(subscriptionProvider);
        ref.invalidate(isProUserAsyncProvider);
        if (mounted) {
          AppSnackBar.success(context, l10n.welcomeToPlan(planName));
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go(AppConfig.dashboard);
          }
        }
        return;
      }

      // ── RevenueCat IAP path (paid plans) ──────────────────────────────
      if (isPaidPlan) {
        final offering = await rcService.getCurrentOffering();
        if (offering == null) {
          // Distinguish three causes so the user gets an actionable message
          // instead of a misleading "check your connection" error:
          //   1. RC init failed / never ran        → "IAP not available"
          //   2. Online but offerings fetch failed → "Could not load plans"
          //   3. Offerings fetched but none marked Current + kDebugMode
          //      → fall back to DB write with a loud warning (so a misconfigured
          //        RevenueCat dashboard doesn't block development)
          if (!rcService.isConfigured) {
            if (mounted) {
              AppSnackBar.error(
                context,
                'In-app purchases are not available right now. '
                'Please restart the app or contact support.',
              );
            }
            return;
          }
          if (kDebugMode) {
            debugPrint('[Subscription] RevenueCat returned no current offering '
                '— falling back to direct DB write in debug mode. Check the '
                'RevenueCat dashboard: Offerings tab → mark an Offering as '
                '"Current" and add a Package whose identifier contains '
                '"$planName".');
            try {
              final db = ref.read(databaseServiceProvider);
              final existing = await db.getSubscription(user.id);
              final now = DateTime.now();
              final periodEnd = now.add(const Duration(days: 30));
              final payload = {
                'plan': planName,
                'status': 'active',
                'current_period_start': now.toIso8601String(),
                'current_period_end': periodEnd.toIso8601String(),
                'cancel_at_period_end': false,
              };
              if (existing == null) {
                await db.createSubscription({'user_id': user.id, ...payload});
              } else {
                await db.updateSubscription(existing.id, payload);
              }
            } catch (e) {
              debugPrint('[Subscription] dev-mode fallback DB write failed '
                  '(RLS hardened? non-fatal): $e');
            }
            ref.invalidate(subscriptionProvider);
            ref.invalidate(isProUserAsyncProvider);
            if (mounted) {
              AppSnackBar.success(context, l10n.welcomeToPlan(planName));
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go(AppConfig.dashboard);
              }
            }
            return;
          }
          if (mounted) {
            AppSnackBar.error(
              context,
              'Could not load available plans. Please check your connection and try again.',
            );
          }
          return;
        }

        // Find the package matching the selected plan.
        final package = offering.availablePackages.where((p) {
          return p.identifier.toLowerCase().contains(planName);
        }).firstOrNull;

        if (package == null) {
          if (mounted) {
            AppSnackBar.error(
              context,
              'The "$planName" plan is not available for purchase right now. '
              'Please try again later.',
            );
          }
          return;
        }

        final success = await rcService.purchasePackage(package);
        if (!success) {
          if (mounted) {
            AppSnackBar.error(context, l10n.purchaseCancelled);
          }
          return;
        }

        // ── Purchase succeeded ─────────────────────────────────────────────
        // CRITICAL FIX: do NOT write to the `subscriptions` table from the
        // client. Migration 009 hardened RLS so only the service_role
        // (RevenueCat webhook) can write. Any client write attempt throws
        // PostgrestException, which used to preempt the `ref.invalidate(...)`
        // calls below — leaving the UI stuck on the previous plan until the
        // user restarted the app (the user-reported "subscription not
        // applied" bug).
        //
        // Instead: invalidate FIRST, then rely on `revenueCatCustomerInfoProvider`
        // (subscribed at app startup) to keep the UI in sync as RevenueCat's
        // SDK observes the entitlement change.
        debugPrint('[Subscription] purchase succeeded for "$planName" — '
            'invalidating subscription providers. Entitlement will be '
            'confirmed via RevenueCat.');
        ref.invalidate(subscriptionProvider);
        ref.invalidate(isProUserAsyncProvider);

        // Verify the entitlement is active via RevenueCat (best-effort).
        bool entitlementActive = false;
        try {
          final customerInfo = await rcService.getCustomerInfo();
          final entitlement = customerInfo?.entitlements.all[planName];
          entitlementActive = entitlement?.isActive == true;
        } catch (e) {
          debugPrint('[Subscription] getCustomerInfo failed (non-fatal): $e');
        }

        if (mounted) {
          if (entitlementActive) {
            AppSnackBar.success(context, l10n.welcomeToPlan(planName));
          } else {
            // Rare: purchase succeeded but entitlement not yet active (RC latency).
            // The customerInfoStream listener will fire shortly and refresh the UI.
            AppSnackBar.info(
              context,
              'Purchase received — your plan will activate shortly.',
            );
          }
          // Navigate away from the subscription screen so the user lands on
          // the dashboard (or wherever they came from). Previously the screen
          // stayed put with just a snackbar — users thought nothing happened.
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go(AppConfig.dashboard);
          }
        }
        return;
      }

      // ── Free plan downgrade ───────────────────────────────────────────
      // CRITICAL FIX: do NOT write to the `subscriptions` table from the
      // client — migration 009 hardened RLS so only the service_role can
      // write. A client write would throw PostgrestException and the UI
      // would stay on the previous plan.
      //
      // For Free downgrades: there's no IAP to perform. We simply invalidate
      // the subscription providers so they re-fetch from the DB (which will
      // be updated by the RevenueCat webhook when the user cancels via the
      // App Store / Google Play, OR immediately if the user was on a
      // dev-mode-granted entitlement). We also call restorePurchases() to
      // force RevenueCat to re-sync the entitlement state.
      try {
        await rcService.restorePurchases();
      } catch (e) {
        debugPrint('[Subscription] restorePurchases during free downgrade '
            'failed (non-fatal): $e');
      }

      ref.invalidate(subscriptionProvider);
      ref.invalidate(isProUserAsyncProvider);

      if (mounted) {
        AppSnackBar.success(context, l10n.downgradedToFree);
        // Navigate away from the subscription screen.
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go(AppConfig.dashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(context, l10n.failedToUpdateSubscription, e);
      }
    } finally {
      if (mounted) setState(() => _pendingPlan = null);
    }
  }

  Future<void> _restorePurchases() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isRestoring = true);
    try {
      // Restore purchases via RevenueCat (queries App Store / Google Play).
      // Per Cahier des Charges Section 3: "RevenueCat — Gestion abonnements".
      final rcService = RevenueCatService();
      if (!rcService.isConfigured) {
        // RevenueCat not configured — cannot restore. Be honest with the user
        // rather than silently refreshing from DB (which could restore a
        // dev-mode-granted entitlement, audit H-3).
        if (mounted) {
          AppSnackBar.info(
            context,
            'In-app purchases are not available on this device.',
          );
        }
        return;
      }

      final restored = await rcService.restorePurchases();
      ref.invalidate(subscriptionProvider);
      ref.invalidate(isProUserAsyncProvider);
      await ref.read(subscriptionProvider.future);

      if (restored) {
        if (mounted) {
          AppSnackBar.success(context, l10n.purchasesRestored);
        }
      } else {
        // No active Pro entitlement found in RevenueCat. The DB row will be
        // updated by the RevenueCat webhook (server-side, service-role) —
        // the client can't write to `subscriptions` (migration 009 hardened
        // RLS). We just invalidate to force a re-fetch.
        ref.invalidate(subscriptionProvider);
        ref.invalidate(isProUserAsyncProvider);
        if (mounted) {
          AppSnackBar.success(context, l10n.noPurchasesToRestore);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(context, l10n.failedToRestorePurchases, e);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final subAsync = ref.watch(subscriptionProvider);
    // Watch isProUserProvider so the "Current plan" badge reflects the
    // RevenueCat SDK state immediately after a purchase, even before the
    // webhook has written the new row to the `subscriptions` table.
    // Without this, the badge stays "Free" until the user restarts the app
    // (the user-reported "subscription not applied" bug).
    final isPro = ref.watch(isProUserProvider);
    final currentPlan = isPro
        ? 'pro'
        : subAsync.maybeWhen(
            data: (s) => s?.plan ?? 'free',
            orElse: () => 'free',
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscription),
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
            label: Text(l10n.restore),
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
              child: Column(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    l10n.chooseYourPlan,
                    style: const TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    l10n.unlockFullPower,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white70),
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
                      l10n.paymentIntegrationPending,
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
              planName: l10n.free,
              price: '\$0',
              period: l10n.forever,
              features: [
                l10n.freePlanFeature1,
                l10n.freePlanFeature2,
                l10n.freePlanFeature3,
                l10n.freePlanFeature4,
                l10n.freePlanFeature5,
              ],
              isCurrentPlan: currentPlan == 'free',
              isLoading: _pendingPlan == 'free',
              isDark: isDark,
              onTap: () => _changePlan('free'),
            ),
            const SizedBox(height: 16),

            // Pro Plan
            _PlanCard(
              planName: l10n.pro,
              price: '\$${AppConfig.proPriceMonthly.toStringAsFixed(2)}',
              period: l10n.perMonth,
              features: [
                l10n.proPlanFeature1,
                l10n.proPlanFeature2,
                l10n.proPlanFeature3,
                l10n.proPlanFeature4,
                l10n.proPlanFeature5,
                l10n.proPlanFeature6,
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
              planName: l10n.enterprise,
              price: '\$${AppConfig.enterprisePriceMonthly.toStringAsFixed(0)}',
              period: l10n.perMonth,
              features: [
                l10n.enterprisePlanFeature1,
                l10n.enterprisePlanFeature2,
                l10n.enterprisePlanFeature3,
                l10n.enterprisePlanFeature4,
                l10n.enterprisePlanFeature5,
                l10n.enterprisePlanFeature6,
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
                      AppSnackBar.info(context, l10n.emailSalesEnterprise);
                    }
                  }
                },
                icon: const Icon(Icons.alternate_email, size: 16),
                label: Text(l10n.contactSalesEnterprise),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.poweredByProducer(AppConfig.producer),
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
    final l10n = AppLocalizations.of(context)!;
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
                          child: Text(
                            l10n.bestValue,
                            style: const TextStyle(
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
                        label: Text(l10n.currentPlan),
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
                            : Text(planName == l10n.free ? l10n.downgrade : l10n.upgradeToPlan(planName)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
