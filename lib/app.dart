import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screensage/features/auth/data/repositories/auth_repository.dart';
import 'package:screensage/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:screensage/features/focus_dna/data/repositories/focus_dna_repository.dart';
import 'package:screensage/main.dart';
import 'core/router/app_router.dart';
import 'core/services/screen_time_service.dart';
import 'core/theme/app_theme.dart';
import 'features/analytics/data/repositories/analytics_repository.dart';
import 'features/analytics/presentation/bloc/analytics_bloc.dart';
import 'features/earned_time/data/repositories/earned_time_repository.dart';
import 'features/earned_time/presentation/bloc/earned_time_bloc.dart';
import 'features/focus_dna/presentation/bloc/focus_dna_bloc.dart';
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
          create: (_) => StreakBloc(StreakRepository()),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) =>
              SettingsBloc(SettingsRepository())..add(SettingsLoadRequested()),
        ),
        BlocProvider<FocusDNABloc>(
            create: (_) => FocusDNABloc(FocusDNARepository()))
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

    // 1. Premium refresh stays global
    await premiumNotifier.refresh();

    if (!mounted) return;

    context.read<SessionBloc>().add(SessionReconcileRequested());

    // 2. Read the native iOS App Group drop-box unconditionally
    final overrides = await ScreenTimeService.getOverrideCount();
    debugPrint('⚠️ Native override check on resume: $overrides');

    if (overrides > 0) {
      // 3. Clear iOS immediately so we never double-count data on multi-resumes
      await ScreenTimeService.resetOverrideCount();

      // 4. Update the active focus session state if one is running
      final sessionBloc = context.read<SessionBloc>();
      if (sessionBloc.state is SessionActive) {
        sessionBloc.add(OverrideDetected(overrides));
      }

      try {
        // 5. Fire your single backend repository handler to update the database records
        // This triggers the global Firebase batch write we mapped out
        await context
            .read<AnalyticsBloc>()
            .repository
            .syncNativeOverrides(overrides);

        // 6. Alert the rest of your UI layers to reload their datasets from the server
        if (mounted) {
          context.read<AnalyticsBloc>().add(AnalyticsRefreshRequested());
          context.read<EarnedTimeBloc>().add(EarnedTimeLoadRequested());
          // If FocusDNABloc is registered higher up or managed under your repositories,
          // dispatch its load request right here as well:
          context.read<FocusDNABloc>().add(FocusDNALoadRequested());
        }
      } catch (e) {
        debugPrint('❌ Failed to push overrides to backend: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
