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
  static const String _proEntitlementId = 'pro';
  static const String _enterpriseEntitlementId = 'enterprise';

  /// Initialize RevenueCat with the user's Supabase user ID.
  /// Call this after sign-in to associate purchases with the user.
  Future<void> initialize(String userId) async {
    if (_initialized) return;

    final apiKey = dotenv.env['REVENUECAT_API_KEY'] ??
        const String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');

    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] No API key found — running in no-op mode. '
          'Set REVENUECAT_API_KEY in .env to enable IAP.');
      return;
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = userId,
      );
      _initialized = true;
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
      final code = e.code ?? '';
      final message = e.message ?? '';
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

  /// Sign out — clears the RevenueCat user ID.
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (_) {
      // Non-fatal — user is signing out anyway.
    }
  }
}
