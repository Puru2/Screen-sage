import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  // print('✅ Env loaded: ${dotenv.env['SUPABASE_URL']}');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');
  await RevenueCatService.init();
  await NotificationService.init();
  await premiumNotifier.refresh();
  try {
    await FirebaseFirestore.instance
        .collection('_ping')
        .doc('test')
        .get(const GetOptions(source: Source.server))
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

  // await Supabase.initialize(
  //   url: AppConstants.supabaseUrl,
  //   anonKey: AppConstants.supabaseAnonKey,
  // );
  // print('✅ Supabase initialized');

  // ⚠️ RevenueCat skipped until you add real API keys to .env
  // await Purchases.configure(...);

  Bloc.observer = AppBlocObserver();
  runApp(PremiumGateProvider(
      notifier: premiumNotifier, child: const ScreenSageApp()));
}
