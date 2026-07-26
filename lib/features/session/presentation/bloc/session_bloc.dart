import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/screen_time_service.dart';
import '../../../earned_time/data/repositories/earned_time_repository.dart';
import '../../../streak/data/repositories/streak_repository.dart';
import '../../data/repositories/session_repository.dart';

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
  final bool completed; // true = natural finish, false = user ended early
  SessionEndRequested({this.completed = false});

  @override
  List<Object?> get props => [completed];
}

class SessionTick extends SessionEvent {}

class SessionAppPickerRequested extends SessionEvent {}

class SessionAuthorizationRequested extends SessionEvent {}

class SessionResetRequested extends SessionEvent {}

class SessionReconcileRequested extends SessionEvent {}

class OverrideDetected extends SessionEvent {
  final int count;
  OverrideDetected(this.count);

  @override
  List<Object?> get props => [count];
}

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
  final String intention;
  final String focusMode;
  final String tag;
  final int overrideCount;
  final DateTime endAt;

  SessionActive({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.durationMinutes,
    required this.sessionId,
    required this.endAt,
    this.intention = '',
    this.focusMode = 'deep',
    this.tag = '',
    this.overrideCount = 0,
  });

  double get progress =>
      1.0 - (remainingSeconds / totalSeconds.clamp(1, totalSeconds));
  int get remainingMinutes => remainingSeconds ~/ 60;
  int get remainingSecondsDisplay => remainingSeconds % 60;

  SessionActive copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    int? durationMinutes,
    String? sessionId,
    String? intention,
    String? focusMode,
    String? tag,
    int? overrideCount,
    DateTime? endAt,
  }) {
    return SessionActive(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      sessionId: sessionId ?? this.sessionId,
      intention: intention ?? this.intention,
      focusMode: focusMode ?? this.focusMode,
      tag: tag ?? this.tag,
      overrideCount: overrideCount ?? this.overrideCount,
      endAt: endAt ?? this.endAt,
    );
  }

  @override
  List<Object?> get props => [
        remainingSeconds,
        totalSeconds,
        durationMinutes,
        sessionId,
        intention,
        focusMode,
        tag,
        overrideCount,
        endAt,
      ];
}

class SessionCompleted extends SessionState {
  final int durationMinutes;
  final int overrides;

  SessionCompleted({
    required this.durationMinutes,
    required this.overrides,
  });

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
    on<SessionReconcileRequested>(_onReconcile);
    on<OverrideDetected>(_onOverrideDetected);
  }

  final SessionRepository _repo;
  final EarnedTimeRepository _earnedRepo = EarnedTimeRepository();
  final StreakRepository _streakRepo = StreakRepository();

  Timer? _timer;
  String? _currentSessionId;
  int _durationMinutes = 0;

  Future<void> _onAuthorize(
    SessionAuthorizationRequested e,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionAuthorizing());

    final status = await ScreenTimeService.getAuthorizationStatus();
    if (status == 'approved') {
      if (!emit.isDone) emit(SessionIdle());
      return;
    }

    final granted = await ScreenTimeService.requestAuthorization();
    if (emit.isDone) return;
    emit(granted ? SessionIdle() : SessionNotAuthorized());
  }

  Future<void> _onAppPicker(
    SessionAppPickerRequested e,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionPickingApps());
    await ScreenTimeService.showAppPicker();
    if (!emit.isDone) emit(SessionIdle());
  }

  Future<void> _onStart(
    SessionStartRequested e,
    Emitter<SessionState> emit,
  ) async {
    try {
      final status = await ScreenTimeService.getAuthorizationStatus();
      if (status != 'approved') {
        emit(SessionAuthorizing());
        final granted = await ScreenTimeService.requestAuthorization();
        if (!granted) {
          emit(SessionNotAuthorized());
          return;
        }
      }

      final selectedCount = await ScreenTimeService.getSelectedAppCount();
      if (selectedCount == 0) {
        emit(SessionError(
          'Select apps to block first, then start your session.',
        ));
        return;
      }

      await ScreenTimeService.resetOverrideCount();

      final started = await ScreenTimeService.startSession(
        durationMinutes: e.durationMinutes,
      );
      if (!started) {
        emit(SessionError(
          'Could not start Screen Time blocking. Please try again.',
        ));
        return;
      }

      final sessionId = await _repo.createSession(
        durationMins: e.durationMinutes,
        intention: e.intention,
        focusMode: e.focusMode,
        tag: e.tag,
      );

      final endAt = DateTime.now().add(Duration(minutes: e.durationMinutes));

      _currentSessionId = sessionId;
      _durationMinutes = e.durationMinutes;

      await NotificationService.scheduleSessionEndNotification(
        sessionId: sessionId.hashCode,
        endAt: endAt,
        durationMinutes: e.durationMinutes,
      );

      _startForegroundTicker(
        sessionId: sessionId,
        totalSeconds: e.durationMinutes * 60,
        durationMinutes: e.durationMinutes,
        endAt: endAt,
        intention: e.intention,
        focusMode: e.focusMode,
        tag: e.tag,
        emit: emit,
      );
    } catch (err) {
      emit(SessionError('Failed to start: $err'));
    }
  }

  void _startForegroundTicker({
    required String sessionId,
    required int totalSeconds,
    required int durationMinutes,
    required DateTime endAt,
    required String intention,
    required String focusMode,
    required String tag,
    required Emitter<SessionState> emit,
  }) {
    _timer?.cancel();

    final remaining =
        endAt.difference(DateTime.now()).inSeconds.clamp(0, totalSeconds);

    emit(SessionActive(
      remainingSeconds: remaining,
      totalSeconds: totalSeconds,
      durationMinutes: durationMinutes,
      sessionId: sessionId,
      endAt: endAt,
      intention: intention,
      focusMode: focusMode,
      tag: tag,
    ));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) return;
      add(SessionTick());
    });
  }

  void _onTick(
    SessionTick e,
    Emitter<SessionState> emit,
  ) {
    final current = state;
    if (current is! SessionActive) return;

    final remaining = current.endAt.difference(DateTime.now()).inSeconds;

    if (remaining <= 0) {
      add(SessionEndRequested(completed: true));
      return;
    }

    emit(current.copyWith(remainingSeconds: remaining));
  }

  Future<void> _onEnd(
    SessionEndRequested e,
    Emitter<SessionState> emit,
  ) async {
    _timer?.cancel();
    _timer = null;

    final sessionId = _currentSessionId;
    if (sessionId == null) {
      emit(SessionIdle());
      return;
    }

    final active = state is SessionActive ? state as SessionActive : null;

    await ScreenTimeService.endSession();
    final overrides = await ScreenTimeService.getOverrideCount();

    int completedMins;
    if (e.completed) {
      completedMins = _durationMinutes;
    } else {
      if (active == null) {
        completedMins = 0;
      } else {
        final elapsedSeconds = active.totalSeconds - active.remainingSeconds;
        completedMins =
            (elapsedSeconds / 60).floor().clamp(0, _durationMinutes);
      }
    }

    try {
      await _repo.finalizeSession(
        sessionId: sessionId,
        completedMins: completedMins,
        overrides: overrides,
        completed: e.completed,
      );
    } catch (err) {
      debugPrint('❌ Failed to finalize session: $err');
    }

    await NotificationService.cancelSessionEndNotification(sessionId.hashCode);

    _currentSessionId = null;

    if (e.completed) {
      try {
        await _earnedRepo.addEarnedMinutes(completedMins);
      } catch (err) {
        debugPrint('❌ Earned minutes failed: $err');
      }

      try {
        await _streakRepo.recordSession();
      } catch (err) {
        debugPrint('❌ Streak update failed: $err');
      }

      try {
        await NotificationService.playCompletionFeedback();
      } catch (err) {
        debugPrint('❌ Completion feedback failed: $err');
      }

      if (!emit.isDone) {
        emit(SessionCompleted(
          durationMinutes: _durationMinutes,
          overrides: overrides,
        ));
      }
    } else {
      if (!emit.isDone) emit(SessionCancelled());
    }
  }

  Future<void> _onReconcile(
    SessionReconcileRequested e,
    Emitter<SessionState> emit,
  ) async {
    try {
      final active = await _repo.getActiveSession();
      if (active == null) return;

      final sessionId = active['id'] as String;
      final durationMins = active['duration_mins'] as int? ?? 0;
      final intention = active['intention'] as String? ?? '';
      final focusMode = active['focus_mode'] as String? ?? 'deep';
      final tag = active['tag'] as String? ?? '';
      final expectedEndAt = (active['expected_end_at'] as Timestamp).toDate();

      final now = DateTime.now();

      if (now.isAfter(expectedEndAt) || now.isAtSameMomentAs(expectedEndAt)) {
        _currentSessionId = sessionId;
        _durationMinutes = durationMins;
        add(SessionEndRequested(completed: true));
        return;
      }

      final remaining = expectedEndAt.difference(now).inSeconds;
      _currentSessionId = sessionId;
      _durationMinutes = durationMins;

      _timer?.cancel();
      emit(SessionActive(
        remainingSeconds: remaining,
        totalSeconds: durationMins * 60,
        durationMinutes: durationMins,
        sessionId: sessionId,
        endAt: expectedEndAt,
        intention: intention,
        focusMode: focusMode,
        tag: tag,
      ));

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (isClosed) return;
        add(SessionTick());
      });
    } catch (err) {
      debugPrint('❌ Session reconcile failed: $err');
    }
  }

  void _onOverrideDetected(
    OverrideDetected e,
    Emitter<SessionState> emit,
  ) {
    final current = state;
    if (current is! SessionActive) return;
    emit(current.copyWith(overrideCount: e.count));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
