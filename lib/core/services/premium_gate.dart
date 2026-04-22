import 'package:flutter/material.dart';
import 'revenue_cat_service.dart';

/// Holds premium state for the session.
/// Wrap your MaterialApp or root with PremiumGateProvider.
class PremiumGateProvider extends InheritedNotifier<PremiumNotifier> {
  const PremiumGateProvider({
    super.key,
    required PremiumNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static PremiumNotifier of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<PremiumGateProvider>();
    assert(provider != null, 'No PremiumGateProvider found in widget tree');
    return provider!.notifier!;
  }
}

class PremiumNotifier extends ChangeNotifier {
  bool _isPremium = false;
  int? _trialDaysLeft; // null = not in trial
  bool _loaded = false;

  bool get isPremium => _isPremium;
  int? get trialDaysLeft => _trialDaysLeft;
  bool get isInTrial => _trialDaysLeft != null;
  bool get loaded => _loaded;

  Future<void> refresh() async {
    // TODO: remove before release
    // _isPremium = true;
    // _trialDaysLeft = null;
    // _loaded = true;
    // notifyListeners();
    // return;

    // real code below — unreachable during testing
    try {
      debugPrint('🔄 PremiumNotifier: refreshing...');
      _isPremium = await RevenueCatService.isPremium();
      _trialDaysLeft = await RevenueCatService.trialDaysRemaining();
      _loaded = true;
      debugPrint(
          '🔄 PremiumNotifier: isPremium=$_isPremium, trial=$_trialDaysLeft');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ PremiumNotifier refresh failed: $e');
      _loaded = true;
      notifyListeners();
    }
    notifyListeners();
  }

  // Call this right after a successful purchase — forces a fresh fetch
  Future<void> refreshAfterPurchase() async {
    debugPrint('💳 refreshAfterPurchase called — forcing CustomerInfo fetch');
    // Small delay to let RevenueCat backend process the transaction
    await Future.delayed(const Duration(milliseconds: 800));
    await refresh();
  }
}
