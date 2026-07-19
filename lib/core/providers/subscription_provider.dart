import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/subscription.dart';
import '../services/revenuecat_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

/// Fetches the user's subscription row from the `subscriptions` DB table.
///
/// This row is populated by RevenueCat webhooks after a successful purchase.
/// It may be `null` if:
///   - The user has never purchased Pro, OR
///   - The webhook hasn't synced yet (can take minutes), OR
///   - The webhook failed (rare but possible)
///
/// For the AUTHORITATIVE Pro status (always current), use
/// [isProUserAsyncProvider] which falls back to RevenueCat directly.
final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.read(databaseServiceProvider);
  return db.getSubscription(user.id);
});

/// The AUTHORITATIVE Pro-status provider.
///
/// Checks THREE sources in order of authority:
///   1. [subscriptionProvider] (DB-backed, fast) — if the subscriptions row
///      exists and says Pro, return true immediately.
///   2. [RevenueCatService.isProUser] (SDK-backed, authoritative) — if the
///      DB says "not Pro" OR the row is missing, query RevenueCat directly.
///      RevenueCat always knows the current entitlement state regardless of
///      DB sync delays.
///
/// This fixes a critical bug where users who HAVE paid for Pro via
/// RevenueCat were being rejected by Pro-gated features (family profiles,
/// AI chat, triage results, export, translation, medical records, QR code,
/// SOS) because the DB row hadn't synced yet. With this provider, paying
/// users are never blocked by a DB sync delay.
///
/// Usage:
///   - In async actions (button taps, form submits): `await ref.read(isProUserAsyncProvider.future)`
///   - In sync build methods: use [isProUserProvider] (which reads the
///     cached value of this provider for instant rendering) OR watch this
///     provider and handle the loading state.
final isProUserAsyncProvider = FutureProvider<bool>((ref) async {
  // Source 1: DB-backed subscription row.
  //
  // CRITICAL FIX (audit C-21): use ref.watch instead of ref.read so that
  // invalidating subscriptionProvider cascades into isProUserAsyncProvider.
  // Previously, after a successful purchase, screens invalidated
  // subscriptionProvider but NOT isProUserAsyncProvider — so the cached
  // "false" persisted and paying users hit ProFeatureGate on the next screen
  // until the app was restarted.
  //
  // FIX (audit M-13): wrap the subscriptionProvider read in try/catch so
  // a DB error (network failure, RLS denial, malformed row) falls through
  // to the RevenueCat check instead of propagating uncaught to consumers.
  Subscription? sub;
  try {
    sub = await ref.watch(subscriptionProvider.future);
  } catch (e) {
    debugPrint('[Subscription] DB read failed, falling through to RC: $e');
  }
  if (sub != null && sub.isProAndNotExpired) {
    return true;
  }

  // Source 2: RevenueCat SDK (authoritative).
  // Even if the DB row is missing or says "free", RevenueCat knows the
  // real entitlement state. This catches the case where the user has
  // paid but the webhook hasn't synced the DB row yet.
  //
  // NOTE: the client-side RevenueCat check is a UX convenience only and is
  // NOT a security boundary — a patched build can spoof it. Sensitive
  // operations (export, translation, AI chat, triage result delivery) MUST
  // additionally verify entitlement server-side via an edge function that
  // re-checks RevenueCat with the secret API key (audit C-2 recommendation).
  try {
    final rcPro = await RevenueCatService().isProUser();
    if (rcPro) {
      debugPrint('[Subscription] Pro confirmed via RevenueCat fallback '
          '(DB row not synced yet or missing)');
      return true;
    }
  } catch (e) {
    debugPrint('[Subscription] RevenueCat Pro check failed: $e');
  }

  return false;
});

/// Synchronous Pro-status provider for use in build methods.
///
/// Returns the CACHED value of [isProUserAsyncProvider]:
///   - `true` if the async provider has resolved with `true`
///   - `false` otherwise (including while loading)
///
/// For the AUTHORITATIVE status in async actions (button taps, form
/// submits), use `await ref.read(isProUserAsyncProvider.future)` instead —
/// that will always do a fresh RevenueCat check if the DB says "not Pro".
final isProUserProvider = Provider<bool>((ref) {
  final proAsync = ref.watch(isProUserAsyncProvider);
  return proAsync.maybeWhen(
    data: (isPro) => isPro,
    orElse: () => false,
  );
});

/// Listens to RevenueCat's `customerInfoStream` and invalidates the
/// subscription provider chain whenever the customer's entitlements change
/// (purchase, webhook sync, restore, expiration, refund).
///
/// This is the **fix for the "user has to restart the app to see their Pro
/// plan applied" bug**. Previously, after a successful purchase, the client
/// tried to write to the `subscriptions` table directly — but migration 009
/// hardened RLS so only the service_role (RevenueCat webhook) can write.
/// The PostgrestException preempted the `ref.invalidate(...)` calls, so the
/// cached `false` value of `isProUserAsyncProvider` persisted until the app
/// was restarted.
///
/// With this listener, the moment RevenueCat's SDK observes the new
/// entitlement (within seconds of `purchasePackage()` returning), the stream
/// fires → both providers invalidate → `isProUserAsyncProvider` re-runs →
/// falls through to `RevenueCatService().isProUser()` → returns `true` →
/// every UI gate that watches `isProUserProvider` rebuilds.
///
/// **Usage**: this provider must be `ref.watch`-ed once at app startup (e.g.
/// in `_VitalSekerAppState.build` or the splash screen) so the stream
/// subscription is alive for the entire app session.
final revenueCatCustomerInfoProvider = StreamProvider<CustomerInfo?>((ref) {
  final rc = RevenueCatService();
  if (!rc.isConfigured) {
    // RevenueCat not configured (no real API key) — nothing to listen to.
    // The debug-mode bypass in the subscription screens handles this case.
    return const Stream.empty();
  }
  try {
    return Purchases.customerInfoStream.map((info) {
      debugPrint('[Subscription] customerInfoStream emitted — invalidating '
          'subscription providers. Pro entitlements: '
          '${info.entitlements.active.keys.join(', ')}');
      ref.invalidate(subscriptionProvider);
      ref.invalidate(isProUserAsyncProvider);
      return info;
    });
  } catch (e) {
    debugPrint('[Subscription] customerInfoStream subscription failed: $e');
    return const Stream.empty();
  }
});
