import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// Single Pro Plan presentation screen.
/// Shows only the Pro plan with its features and a subscribe button.
///
/// SECURITY (audit C-7 fix): the previous implementation wrote {plan:'pro'}
/// directly to the subscriptions table WITHOUT going through RevenueCat. Any
/// user could tap "Subscribe" and instantly unlock every Pro feature without
/// paying. This version requires a successful RevenueCat purchase before any
/// DB write happens. If RevenueCat is not configured, the button fails
/// closed with a clear error.
class ProPlanScreen extends ConsumerStatefulWidget {
  const ProPlanScreen({super.key});

  @override
  ConsumerState<ProPlanScreen> createState() => _ProPlanScreenState();
}

class _ProPlanScreenState extends ConsumerState<ProPlanScreen> {
  bool _isSubscribing = false;

  Future<void> _subscribe() async {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.error(context, 'Please sign in to subscribe.');
      return;
    }

    // CRITICAL (audit C-7 fix): require RevenueCat in production. In debug
    // mode, allow direct DB write for testing without RevenueCat configured.
    //
    // We gate on `hasRealApiKey` (not `isConfigured`) because Purchases.configure()
    // can succeed even with a bogus/placeholder key — leaving isConfigured=true
    // while getOfferings() returns null. That combination previously defeated
    // the debug bypass and surfaced a misleading "Could not load plans" error.
    final rcService = RevenueCatService();
    if (!rcService.hasRealApiKey && !kDebugMode) {
      AppSnackBar.error(
        context,
        l10n.inAppPurchasesNotAvailable,
      );
      return;
    }

    setState(() => _isSubscribing = true);
    try {
      // In debug mode without a real RevenueCat API key, skip the IAP flow and
      // write directly to the DB so the app can be tested.
      if (!rcService.hasRealApiKey && kDebugMode) {
        try {
          final db = ref.read(databaseServiceProvider);
          final existing = await db.getSubscription(user.id);
          final now = DateTime.now();
          final periodEnd = now.add(const Duration(days: 30));
          final payload = {
            'plan': 'pro',
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
          debugPrint('[ProPlan] dev-mode DB write failed (RLS hardened? '
              'non-fatal — invalidating providers so isProUserAsyncProvider '
              're-evaluates): $e');
        }
        ref.invalidate(subscriptionProvider);
        ref.invalidate(isProUserAsyncProvider);
        if (mounted) {
          AppSnackBar.success(context, l10n.welcomeToPlan('pro'));
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go(AppConfig.dashboard);
          }
        }
        return;
      }

      // Fetch the current offering from RevenueCat.
      final offering = await rcService.getCurrentOffering();
      if (offering == null) {
        // Distinguish three causes:
        //   1. RC init failed / never ran        → "IAP not available"
        //   2. Online but offerings fetch failed → "Could not load plans"
        //   3. Offerings fetched but none marked Current + kDebugMode
        //      → fall back to DB write (so a misconfigured RevenueCat dashboard
        //        doesn't block development)
        if (!rcService.isConfigured) {
          if (mounted) {
            AppSnackBar.error(
              context,
              l10n.inAppPurchasesNotAvailable,
            );
          }
          return;
        }
        if (kDebugMode) {
          debugPrint('[ProPlan] RevenueCat returned no current offering — '
              'falling back to direct DB write in debug mode. Check the '
              'RevenueCat dashboard: Offerings tab → mark an Offering as '
              '"Current" and add a Package whose identifier contains "pro".');
          try {
            final db = ref.read(databaseServiceProvider);
            final existing = await db.getSubscription(user.id);
            final now = DateTime.now();
            final periodEnd = now.add(const Duration(days: 30));
            final payload = {
              'plan': 'pro',
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
            debugPrint('[ProPlan] dev-mode fallback DB write failed (RLS '
                'hardened? non-fatal): $e');
          }
          ref.invalidate(subscriptionProvider);
          ref.invalidate(isProUserAsyncProvider);
          if (mounted) {
            AppSnackBar.success(context, l10n.welcomeToPlan('pro'));
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
            l10n.couldNotLoadPlans,
          );
        }
        return;
      }

      // Find the Pro package. Try identifier "pro" first, then fall back
      // to any package whose identifier contains "pro".
      final package = offering.availablePackages.where((p) {
        return p.identifier.toLowerCase() == 'pro' ||
               p.identifier.toLowerCase().contains('pro');
      }).firstOrNull;

      if (package == null) {
        if (mounted) {
          AppSnackBar.error(
            context,
            l10n.planNotAvailable('pro'),
          );
        }
        return;
      }

      // Launch the platform paywall. purchasePackage throws on failure
      // (except user cancellation, which returns false).
      bool purchaseSucceeded = false;
      try {
        purchaseSucceeded = await rcService.purchasePackage(package);
      } catch (e) {
        debugPrint('[ProPlan] purchasePackage threw: $e');
        rethrow;
      }
      if (!purchaseSucceeded) {
        // User cancelled — no error snackbar, just return.
        return;
      }

      // ── Purchase succeeded ──────────────────────────────────────────────
      // CRITICAL FIX: do NOT write to the `subscriptions` table from the
      // client. Migration 009 hardened RLS so only the service_role
      // (RevenueCat webhook) can write. Any client write attempt throws
      // PostgrestException, which used to preempt the `ref.invalidate(...)`
      // calls below — leaving the UI stuck on "Free" until the user
      // restarted the app (the user-reported "subscription not applied"
      // bug).
      //
      // Instead: rely on two mechanisms to propagate the new entitlement:
      //   1. `revenueCatCustomerInfoProvider` (subscribed at app startup)
      //      listens to `Purchases.customerInfoStream` and invalidates
      //      `subscriptionProvider` + `isProUserAsyncProvider` the instant
      //      RevenueCat's SDK observes the new entitlement (within seconds
      //      of purchasePackage returning).
      //   2. The explicit `ref.invalidate(...)` calls below cover the case
      //      where the stream event has already fired (race) and provide
      //      an immediate UI refresh on this screen.
      //
      // The webhook (server-side, service-role) will eventually write the
      // authoritative row to the `subscriptions` table; when it does, the
      // next `subscriptionProvider` fetch will pick it up.
      debugPrint('[ProPlan] purchase succeeded — invalidating subscription '
          'providers. Entitlement will be confirmed via RevenueCat.');
      ref.invalidate(subscriptionProvider);
      ref.invalidate(isProUserAsyncProvider);
      // Note: userProfileProvider does NOT need invalidation — UserProfile
      // has no `plan` field; the plan lives only on `subscriptions`.

      // Verify the entitlement is active via RevenueCat (best-effort).
      bool entitlementActive = false;
      try {
        final customerInfo = await rcService.getCustomerInfo();
        final entitlement = customerInfo?.entitlements.all['pro'];
        entitlementActive = entitlement?.isActive == true;
      } catch (e) {
        debugPrint('[ProPlan] getCustomerInfo failed (non-fatal): $e');
      }

      if (mounted) {
        if (entitlementActive) {
          AppSnackBar.success(context, l10n.welcomeToPlan('pro'));
        } else {
          // Rare: purchase succeeded but entitlement not yet active (RC latency).
          // The customerInfoStream listener will fire shortly and refresh the UI.
          AppSnackBar.info(
            context,
            'Purchase received — your Pro features will activate shortly.',
          );
        }
        // Navigate back instead of wiping the stack — preserves the user's
        // original destination (e.g. they came from the Family screen to
        // subscribe, they expect to return to Family after subscribing).
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go(AppConfig.dashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not complete purchase. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

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
        title: Text(l10n.pro, style: AppTextStyles.heading3),
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
              l10n.pro,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${AppConfig.proPriceMonthly}/month',
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
                        'Subscribe to Pro — \$${AppConfig.proPriceMonthly}/month',
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
                l10n.viewAllPlans,
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
