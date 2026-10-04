import 'package:cloud_firestore/cloud_firestore.dart' as source;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'app.dart';
import 'core/observer/app_bloc_observer.dart';
import 'core/services/notification_service.dart';
import 'core/services/premium_gate.dart';
import 'core/services/revenue_cat_service.dart';
import 'firebase_options.dart';

final premiumNotifier = PremiumNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');
  await RevenueCatService.init();
  await NotificationService.init();
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      try {
        await Purchases.logIn(user.uid);
      } catch (e) {
        debugPrint('⚠️ RevenueCat logIn on restore failed: $e');
      }
      await premiumNotifier.refresh();
    } else {
      if (await Purchases.isConfigured) {
        try {
          await Purchases.logOut();
        } catch (_) {}
      }
      premiumNotifier.reset();
    }
  });
  try {
    // FirebaseAuth.instance.signOut();  // incase firebase persists with previous user auth token then logout like this and comment it again
    await source.FirebaseFirestore.instance
        .collection('_ping')
        .doc('test')
        .get(const source.GetOptions(source: source.Source.server))
        .timeout(const Duration(seconds: 5));
    debugPrint('[Firestore] ✅ Server reachable');
  } catch (e) {
    debugPrint('[Firestore] ❌ Server NOT reachable: $e');
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF080C14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  Bloc.observer = AppBlocObserver();
  runApp(PremiumGateProvider(
      notifier: premiumNotifier, child: const ScreenSageApp()));
}
