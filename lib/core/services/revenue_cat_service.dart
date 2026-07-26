import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:screensage/core/constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class RevenueCatService {
  static final String _iosApiKey = AppConstants.revenueCatAppleApiKey;
  static final String _entitlementId = AppConstants.entitlementPremium;

  static Future<void> init() async {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );
    final config = PurchasesConfiguration(_iosApiKey);
    await Purchases.configure(config);
    debugPrint('✅ RevenueCat initialized');
  }

  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      return null;
    }
  }

  /// Returns days left in trial, null if not in trial
  static Future<int?> trialDaysRemaining() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.active[_entitlementId];
      if (entitlement == null) return null;

      // periodType is an enum — trial means free trial period
      if (entitlement.periodType != PeriodType.trial) return null;

      // expirationDate is String? in format "2024-01-01T00:00:00Z"
      final expiryString = entitlement.expirationDate;
      if (expiryString == null) return null;

      final expiry = DateTime.tryParse(expiryString);
      if (expiry == null) return null;

      final remaining = expiry.difference(DateTime.now()).inDays;
      return remaining.clamp(0, 7);
    } catch (e) {
      debugPrint('RevenueCat trialDaysRemaining error: $e');
      return null;
    }
  }

  static Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('RevenueCat getPackages error: $e');
      return [];
    }
  }

  static Future<bool> purchase(Package package) async {
    try {
      final CustomerInfo info = await Purchases.purchasePackage(package);
      return info.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      if (e is PlatformException) {
        final code = PurchasesErrorHelper.getErrorCode(e);
        if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      }
      rethrow;
    }
  }

  static Future<bool> restore() async {
    try {
      final CustomerInfo info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }

  static Future<void> identifyUser(String uid) async {
    try {
      await Purchases.logIn(uid);
      debugPrint('✅ RevenueCat identified: $uid');
    } catch (e) {
      debugPrint('RevenueCat identify error: $e');
    }
  }

  static Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat logOut error: $e');
    }
  }

  /// Opens iOS subscription management page in App Store
  static Future<void> openManageSubscriptions() async {
    const url = 'https://apps.apple.com/account/subscriptions';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // In revenue_cat_service.dart

  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      debugPrint("info from ispremium : $info");
      final entitlement = info.entitlements.active[_entitlementId];
      final active = entitlement != null;

      // Debug — print exactly what RevenueCat sees
      debugPrint(
          '🔑 Active entitlements: ${info.entitlements.active.keys.toList()}');
      debugPrint('🔑 isPremium: $active');
      if (entitlement != null) {
        debugPrint('🔑 Expires: ${entitlement.expirationDate}');
        debugPrint('🔑 Product: ${entitlement.productIdentifier}');
      }

      await _syncPremiumToFirestore(active, entitlement?.expirationDate);
      return active;
    } catch (e) {
      debugPrint('❌ isPremium check failed: $e');
      return false;
    }
  }

  static Future<void> _syncPremiumToFirestore(
      bool isPremium, String? expirationDate) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DateTime? validTill;
      if (expirationDate != null) {
        validTill = DateTime.tryParse(expirationDate);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': isPremium,
        'premiumUpdatedAt': FieldValue.serverTimestamp(),
        'premiumValidTill': validTill != null
            ? Timestamp.fromDate(validTill)
            : null, // null = monthly (no known end) or expired
        'premiumProductId': isPremium ? await _getActiveProductId() : null,
      }, SetOptions(merge: true));

      debugPrint(
          '✅ Firestore synced → isPremium: $isPremium, validTill: $validTill');
    } catch (e) {
      debugPrint('❌ Firestore sync failed: $e');
    }
  }

  static Future<String?> _getActiveProductId() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active[_entitlementId]?.productIdentifier;
    } catch (_) {
      return null;
    }
  }
}
