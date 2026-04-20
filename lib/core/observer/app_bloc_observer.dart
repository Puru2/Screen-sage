import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    // In production, send to PostHog/Sentry
    debugPrint('[BlocError] ${bloc.runtimeType}: $error');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    // Uncomment to debug state changes:
    // debugPrint('[BlocChange] ${bloc.runtimeType}: $change');
  }
}
