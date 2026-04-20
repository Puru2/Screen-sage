import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/notification_service.dart';
import '../../../earned_time/data/repositories/earned_time_repository.dart';
import '../../../streak/data/repositories/streak_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../../../core/services/screen_time_service.dart';

// ── Events ────────────────────────────────────────────────────────
abstract class SessionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SessionStartRequested extends SessionEvent {
  final int durationMinutes;
  final String intention;
  final String focusMode;
  final String tag;

  SessionStartRequested(
    this.durationMinutes, {
    this.intention = '',
    this.focusMode = 'deep',
    this.tag = '',
  });

  @override
  List<Object?> get props => [durationMinutes, intention, focusMode, tag];
}

class SessionEndRequested extends SessionEvent {
  final bool completed;
  SessionEndRequested({this.completed = false});
  @override
  List<Object?> get props => [completed];
}

class SessionTick extends SessionEvent {
  final int remainingSeconds;
  SessionTick(this.remainingSeconds);
  @override
  List<Object?> get props => [remainingSeconds];
}

class SessionAppPickerRequested extends SessionEvent {}

class SessionAuthorizationRequested extends SessionEvent {}

class SessionResetRequested extends SessionEvent {}

// ── States ────────────────────────────────────────────────────────
abstract class SessionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SessionIdle extends SessionState {}

class SessionAuthorizing extends SessionState {}

class SessionNotAuthorized extends SessionState {}

class SessionPickingApps extends SessionState {}

class SessionActive extends SessionState {
  final int remainingSeconds;
  final int totalSeconds;
  final int durationMinutes;
  final String sessionId;
  final String intention; // ← add
  final String focusMode; // ← add
  final String tag;

  SessionActive(
      {required this.remainingSeconds,
      required this.totalSeconds,
      required this.durationMinutes,
      required this.sessionId,
      this.intention = '',
      this.focusMode = 'deep',
      this.tag = ''});

  double get progress =>
      1.0 - (remainingSeconds / totalSeconds.clamp(1, totalSeconds));
  int get remainingMinutes => remainingSeconds ~/ 60;
  int get remainingSecondsDisplay => remainingSeconds % 60;

  @override
  List<Object?> get props => [
        remainingSeconds,
        totalSeconds,
        durationMinutes,
        sessionId,
        intention,
        focusMode,
        tag
      ];
}

class SessionCompleted extends SessionState {
  final int durationMinutes;
  final int overrides;
  SessionCompleted({required this.durationMinutes, required this.overrides});
  @override
  List<Object?> get props => [durationMinutes, overrides];
}

class SessionCancelled extends SessionState {}

class SessionError extends SessionState {
  final String message;
  SessionError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Bloc ──────────────────────────────────────────────────────────
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._repo) : super(SessionIdle()) {
    on<SessionResetRequested>((_, emit) => emit(SessionIdle()));
    on<SessionAuthorizationRequested>(_onAuthorize);
    on<SessionAppPickerRequested>(_onAppPicker);
    on<SessionStartRequested>(_onStart);
    on<SessionTick>(_onTick);
    on<SessionEndRequested>(_onEnd);
  }

  final SessionRepository _repo;
  Timer? _timer;
  String? _currentSessionId;
  int _durationMinutes = 0;
  final EarnedTimeRepository _earnedRepo = EarnedTimeRepository();
  final StreakRepository _streakRepo = StreakRepository();

  Future<void> _onAuthorize(
    SessionAuthorizationRequested e,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionAuthorizing());
    final status = await ScreenTimeService.getAuthorizationStatus();
    if (status == 'approved') {
      emit(SessionIdle());
    } else {
      final granted = await ScreenTimeService.requestAuthorization();
      emit(granted ? SessionIdle() : SessionNotAuthorized());
    }
  }

  Future<void> _onAppPicker(
    SessionAppPickerRequested e,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionPickingApps());
    await ScreenTimeService.showAppPicker();
    emit(SessionIdle());
  }

  Future<void> _onStart(
    SessionStartRequested e,
    Emitter<SessionState> emit,
  ) async {
    debugPrint('🟢 SessionBloc._onStart — ${e.durationMinutes} min');

    try {
      // Step 1: Auth check
      final status = await ScreenTimeService.getAuthorizationStatus();
      debugPrint('🔐 ScreenTime status: $status');

      if (status != 'approved') {
        emit(SessionAuthorizing());
        final granted = await ScreenTimeService.requestAuthorization();
        debugPrint('🔐 Auth granted: $granted');
        if (!granted) {
          emit(SessionNotAuthorized());
          return;
        }
      }

      // Step 2: Reset overrides
      await ScreenTimeService.resetOverrideCount();
      debugPrint('🔄 Override count reset');

      // Step 3: Save to Firestore
      debugPrint('💾 Creating Firestore session...');
      final sessionId = await _repo.createSession(
        durationMins: e.durationMinutes,
        intention: e.intention, // ← from event, not hardcoded
        focusMode: e.focusMode,
        tag: e.tag,
      );
      debugPrint('✅ Firestore session created: $sessionId');

      _currentSessionId = sessionId;
      _durationMinutes = e.durationMinutes;

      // Step 4: Start native blocking
      debugPrint('📱 Starting native Screen Time blocking...');
      final started = await ScreenTimeService.startSession(
        durationMinutes: e.durationMinutes,
      );
      debugPrint('📱 Native blocking started: $started');

      if (!started) {
        // Clean up orphaned Firestore record
        await _repo.completeSession(
          sessionId: sessionId,
          completedMins: 0,
          overrides: 0,
          completed: false,
        );
        await NotificationService.cancelStreakRisk();
        _currentSessionId = null;
        emit(SessionError(
          'Select apps to block first, then start your session.',
        ));
        return;
      }

      // Step 5: Start timer
      debugPrint('⏱ Starting timer: ${e.durationMinutes * 60}s');
      _startTimer(e.durationMinutes * 60, sessionId, e.intention, e.focusMode,
          e.tag, emit);
    } catch (err, stack) {
      debugPrint('❌ Session start failed: $err');
      debugPrint('Stack: $stack');
      emit(SessionError('Failed to start: ${err.toString()}'));
    }
  }

  void _startTimer(
    int totalSeconds,
    String sessionId,
    String intention,
    String focusMode,
    String tag,
    Emitter<SessionState> emit,
  ) {
    int remaining = totalSeconds;
    emit(SessionActive(
      remainingSeconds: remaining,
      totalSeconds: totalSeconds,
      durationMinutes: _durationMinutes,
      sessionId: sessionId,
      intention: intention,
      focusMode: focusMode,
      tag: tag,
    ));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        add(SessionEndRequested(completed: true));
      } else {
        add(SessionTick(remaining));
      }
    });
  }

  void _onTick(SessionTick e, Emitter<SessionState> emit) {
    if (state is SessionActive) {
      final s = state as SessionActive;
      emit(SessionActive(
        remainingSeconds: e.remainingSeconds,
        totalSeconds: s.totalSeconds,
        durationMinutes: s.durationMinutes,
        sessionId: s.sessionId,
        intention: s.intention,
        focusMode: s.focusMode,
        tag: s.tag,
      ));
    }
  }

  Future<void> _onEnd(
    SessionEndRequested e,
    Emitter<SessionState> emit,
  ) async {
    debugPrint('🔴 SessionBloc._onEnd — completed: ${e.completed}');
    _timer?.cancel();
    _timer = null;

    final sessionId = _currentSessionId;
    if (sessionId == null) {
      debugPrint('⚠️ No active session ID — resetting to idle');
      emit(SessionIdle());
      return;
    }

    // Stop native blocking
    await ScreenTimeService.endSession();
    debugPrint('📱 Native blocking stopped');

    // Get override count
    final overrides = await ScreenTimeService.getOverrideCount();
    debugPrint('🔢 Overrides during session: $overrides');

    // Calculate completed minutes
    int completedMins = _durationMinutes;
    if (state is SessionActive) {
      final s = state as SessionActive;
      final elapsedSeconds = s.totalSeconds - s.remainingSeconds;
      // If completed naturally (timer ran out), award full duration
      completedMins = e.completed
          ? _durationMinutes // ✅ full duration
          : (elapsedSeconds / 60).floor(); // partial if ended early
    }
    debugPrint('⏱ Completed: ${completedMins}min of ${_durationMinutes}min');

    // Save to Firestore
    try {
      await _repo.completeSession(
        sessionId: sessionId,
        completedMins: completedMins,
        overrides: overrides,
        completed: e.completed,
      );
      debugPrint('✅ Session saved to Firestore');
    } catch (err) {
      debugPrint('❌ Failed to save session: $err');
      // Don't fail the whole flow — session still ended
    }

    _currentSessionId = null;

    if (e.completed) {
      // Award earned time
      try {
        await _earnedRepo.addEarnedMinutes(completedMins);
        debugPrint('💰 Awarded $completedMins earned minutes');
      } catch (err) {
        debugPrint('❌ Earned time failed: $err');
      }

      // Record streak
      try {
        final streak = await _streakRepo.recordSession();
        debugPrint('🔥 Streak: ${streak.currentStreak} days');
      } catch (err) {
        debugPrint('❌ Streak record failed: $err');
      }

      emit(SessionCompleted(
        durationMinutes: _durationMinutes,
        overrides: overrides,
      ));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
