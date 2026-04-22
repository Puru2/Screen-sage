import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screensage/features/auth/data/repositories/auth_repository.dart';
import 'package:screensage/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:screensage/main.dart';
import 'core/router/app_router.dart';
import 'core/services/screen_time_service.dart';
import 'core/theme/app_theme.dart';
import 'features/analytics/data/repositories/analytics_repository.dart';
import 'features/analytics/presentation/bloc/analytics_bloc.dart';
import 'features/earned_time/data/repositories/earned_time_repository.dart';
import 'features/earned_time/presentation/bloc/earned_time_bloc.dart';
import 'features/session/data/repositories/session_repository.dart';
import 'features/session/presentation/bloc/session_bloc.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/streak/data/repositories/streak_repository.dart';
import 'features/streak/presentation/bloc/streak_bloc.dart';

class ScreenSageApp extends StatelessWidget {
  const ScreenSageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc(AuthRepository())),
        BlocProvider<SessionBloc>(
          create: (_) => SessionBloc(SessionRepository()),
        ),
        BlocProvider<AnalyticsBloc>(
          create: (_) => AnalyticsBloc(AnalyticsRepository()),
        ),
        BlocProvider<EarnedTimeBloc>(
          create: (_) => EarnedTimeBloc(EarnedTimeRepository())
            ..add(EarnedTimeLoadRequested()),
        ),
        BlocProvider<StreakBloc>(
          create: (_) =>
              StreakBloc(StreakRepository())..add(StreakLoadRequested()),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) =>
              SettingsBloc(SettingsRepository())..add(SettingsLoadRequested()),
        ),
      ],
      child: _AppLifecycleBridge(
        // ← wrap MaterialApp with this
        child: MaterialApp.router(
          title: 'ScreenSage',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}

// Add this widget at the bottom of app.dart:
class _AppLifecycleBridge extends StatefulWidget {
  const _AppLifecycleBridge({required this.child});
  final Widget child;

  @override
  State<_AppLifecycleBridge> createState() => _AppLifecycleBridgeState();
}

class _AppLifecycleBridgeState extends State<_AppLifecycleBridge>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _onResume();
  }

  Future<void> _onResume() async {
    debugPrint('📱 App resumed');

    // Premium refresh — premiumNotifier is global, always safe
    await premiumNotifier.refresh();

    // Override check — context is inside MultiBlocProvider ✅
    if (!mounted) return;
    final sessionBloc = context.read<SessionBloc>();
    if (sessionBloc.state is SessionActive) {
      final overrides = await ScreenTimeService.getOverrideCount();
      debugPrint('⚠️ Override check on resume: $overrides');
      if (overrides > 0) {
        sessionBloc.add(OverrideDetected(overrides));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
