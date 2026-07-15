import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// RevenueCat service for subscription management.
///
/// Per Cahier des Charges Section 3: "Paiements — RevenueCat — Abonnements
/// iOS & Android, paywalls, analytics".
///
/// This service handles:
/// - Initializing the RevenueCat SDK with the public API key
/// - Fetching available packages (Pro monthly, Pro annual, Enterprise)
/// - Purchasing a package
/// - Restoring previous purchases
/// - Checking the current entitlement (Pro / Free)
///
/// The API key is loaded from .env or String.fromEnvironment. If not set,
/// all methods return safe defaults (Free tier) — this allows the app to
/// run in development without a RevenueCat account.
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _initialized = false;
  String? _currentUserId;
  static const String _proEntitlementId = 'pro';
  static const String _enterpriseEntitlementId = 'enterprise';

  /// Initialize RevenueCat with the user's Supabase user ID.
  /// Call this after sign-in to associate purchases with the user.
  ///
  /// Safety: if a different user signs in after a previous session (e.g. user A
  /// signs out, user B signs in on the same device), we MUST re-initialize with
  /// the new appUserID so entitlements are not leaked across accounts. The SDK
  /// supports this via `Purchases.logIn(newUserId)`.
  Future<void> initialize(String userId) async {
    final apiKey = dotenv.env['REVENUECAT_API_KEY'] ??
        const String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');

    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] No API key found — running in no-op mode. '
          'Set REVENUECAT_API_KEY in .env to enable IAP.');
      return;
    }

    // Already initialized for the same user — nothing to do.
    if (_initialized && _currentUserId == userId) return;

    try {
      if (!_initialized) {
        // First initialization this app session.
        await Purchases.configure(
          PurchasesConfiguration(apiKey)..appUserID = userId,
        );
      } else {
        // Already initialized for a DIFFERENT user — switch appUserID.
        // Purchases.logIn handles the user switch and returns the new CustomerInfo.
        // If the new appUserID was already seen on this device, RC returns
        // `created=false` and merges the anon+named histories safely.
        try {
          await Purchases.logIn(userId);
        } on PlatformException catch (e) {
          // Receiving the same appUserID twice can raise `PlatformException`
          // with code `PurchaseAlreadyLinkedToAnotherUserSubscriberError` —
          // rare in our flow (we only call logIn after signOut). If it happens,
          // fall back to logOut + configure.
          debugPrint('[RevenueCat] logIn failed (${e.code}), reconfiguring: ${e.message}');
          await Purchases.logOut();
          await Purchases.configure(
            PurchasesConfiguration(apiKey)..appUserID = userId,
          );
        }
      }
      _initialized = true;
      _currentUserId = userId;
      debugPrint('[RevenueCat] Initialized successfully for user $userId');
    } catch (e) {
      debugPrint('[RevenueCat] Initialization failed: $e');
    }
  }

  /// Whether RevenueCat is properly configured (API key set + init succeeded).
  bool get isConfigured => _initialized;

  /// Get the current offering (available packages for purchase).
  /// Returns null if RevenueCat is not configured or no offerings exist.
  Future<Offering?> getCurrentOffering() async {
    if (!_initialized) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      debugPrint('[RevenueCat] Failed to fetch offerings: $e');
      return null;
    }
  }

  /// Purchase a specific package. Returns true on success.
  Future<bool> purchasePackage(Package package) async {
    if (!_initialized) return false;
    try {
      await Purchases.purchasePackage(package);
      return true;
    } on PlatformException catch (e) {
      // PurchasesErrorCode is an enum, not a throwable type — the purchases_flutter
      // package throws PlatformException. Check the code/message for cancellation.
      // Note: e.code and e.message may or may not be nullable depending on the
      // platform version, so we cast to String to be safe.
      final code = e.code as String? ?? '';
      final message = e.message as String? ?? '';
      if (code.contains('purchaseCancelled') || message.contains('cancel')) {
        return false; // User cancelled — not an error
      }
      debugPrint('[RevenueCat] Purchase failed: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[RevenueCat] Purchase error: $e');
      rethrow;
    }
  }

  /// Restore previous purchases. Returns true if a Pro entitlement was found.
  Future<bool> restorePurchases() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _hasProEntitlement(customerInfo);
    } catch (e) {
      debugPrint('[RevenueCat] Restore failed: $e');
      return false;
    }
  }

  /// Check if the current user has the Pro entitlement.
  Future<bool> isProUser() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _hasProEntitlement(customerInfo);
    } catch (e) {
      debugPrint('[RevenueCat] Failed to check entitlement: $e');
      return false;
    }
  }

  /// Check if the current user has the Enterprise entitlement.
  Future<bool> isEnterpriseUser() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_enterpriseEntitlementId]?.isActive == true;
    } catch (e) {
      return false;
    }
  }

  /// Get the current customer info (contains all entitlements + expiration).
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      return null;
    }
  }

  bool _hasProEntitlement(CustomerInfo info) {
    return info.entitlements.all[_proEntitlementId]?.isActive == true;
  }

  /// Sign out — clears the RevenueCat user ID and resets internal state so
  /// the next sign-in re-initializes with the new user's appUserID.
  ///
  /// CRITICAL: if we don't reset `_initialized` and `_currentUserId` here, the
  /// next call to `initialize(newUserId)` will early-return and RevenueCat
  /// will continue to report the PREVIOUS user's entitlements — leaking
  /// subscription state across accounts on shared devices.
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      // Non-fatal — user is signing out anyway. We still reset state below so
      // the next sign-in starts fresh.
      debugPrint('[RevenueCat] logOut on signOut failed (non-fatal): $e');
    }
    _initialized = false;
    _currentUserId = null;
  }
}
