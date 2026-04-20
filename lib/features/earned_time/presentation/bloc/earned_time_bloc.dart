import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/earned_time_repository.dart';
import '../../../../core/services/screen_time_service.dart';

// ── Events ────────────────────────────────────────────────────────
abstract class EarnedTimeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class EarnedTimeLoadRequested extends EarnedTimeEvent {}

class EarnedTimeDataUpdated extends EarnedTimeEvent {
  final EarnedTimeData data;
  EarnedTimeDataUpdated(this.data);
  @override
  List<Object?> get props => [data];
}

class EarnedTimeSpendRequested extends EarnedTimeEvent {
  final int minutes;
  EarnedTimeSpendRequested(this.minutes);
  @override
  List<Object?> get props => [minutes];
}

class EarnedTimeFreeSessionEnded extends EarnedTimeEvent {}

class EarnedTimeTick extends EarnedTimeEvent {}

// ── States ────────────────────────────────────────────────────────
abstract class EarnedTimeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class EarnedTimeInitial extends EarnedTimeState {}

class EarnedTimeLoading extends EarnedTimeState {}

class EarnedTimeLoaded extends EarnedTimeState {
  final EarnedTimeData data;
  EarnedTimeLoaded(this.data);
  @override
  List<Object?> get props => [data];
}

class EarnedTimeSpending extends EarnedTimeState {
  final EarnedTimeData data;
  EarnedTimeSpending(this.data);
  @override
  List<Object?> get props => [data];
}

class EarnedTimeFreeActive extends EarnedTimeState {
  final EarnedTimeData data;
  final int remainingSeconds;
  EarnedTimeFreeActive({
    required this.data,
    required this.remainingSeconds,
  });
  @override
  List<Object?> get props => [data, remainingSeconds];
}

class EarnedTimeError extends EarnedTimeState {
  final String message;
  EarnedTimeError(this.message);
  @override
  List<Object?> get props => [message];
}

class EarnedTimeFreeSessionExpired extends EarnedTimeState {
  final EarnedTimeData data;
  EarnedTimeFreeSessionExpired(this.data);
  @override
  List<Object?> get props => [data];
}

class EarnedTimeInsufficientBalance extends EarnedTimeState {
  final EarnedTimeData data;
  EarnedTimeInsufficientBalance(this.data);
  @override
  List<Object?> get props => [data];
}

// ── Bloc ─────────────────────────────────────────────────────────
class EarnedTimeBloc extends Bloc<EarnedTimeEvent, EarnedTimeState> {
  EarnedTimeBloc(this._repo) : super(EarnedTimeInitial()) {
    on<EarnedTimeLoadRequested>(_onLoad);
    on<EarnedTimeDataUpdated>(_onDataUpdated);
    on<EarnedTimeSpendRequested>(_onSpend);
    on<EarnedTimeFreeSessionEnded>(_onFreeSessionEnd);
    on<EarnedTimeTick>(_onTick);
  }

  final EarnedTimeRepository _repo;
  StreamSubscription<EarnedTimeData>? _dataSub;
  Timer? _tickTimer;

  Future<void> _onLoad(
    EarnedTimeLoadRequested e,
    Emitter<EarnedTimeState> emit,
  ) async {
    emit(EarnedTimeLoading());
    try {
      // Initial fetch
      final data = await _repo.getData();
      _emitCorrectState(data, emit);

      // Subscribe to real-time updates
      await _dataSub?.cancel();
      _dataSub = _repo.watchData().listen(
            (data) => add(EarnedTimeDataUpdated(data)),
          );

      // If free session active, start tick timer
      if (data.hasFreeSession) _startTicker();
    } catch (err) {
      emit(EarnedTimeError(err.toString()));
    }
  }

  void _onDataUpdated(
    EarnedTimeDataUpdated e,
    Emitter<EarnedTimeState> emit,
  ) {
    debugPrint('💰 EarnedTime data updated: balance=${e.data.balanceMins}');
    _emitCorrectState(e.data, emit);
    if (e.data.hasFreeSession) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  Future<void> _onSpend(
    EarnedTimeSpendRequested e,
    Emitter<EarnedTimeState> emit,
  ) async {
    final currentData = _getCurrentData();
    if (currentData == null) return;

    emit(EarnedTimeSpending(currentData));

    try {
      final success = await _repo.spendMinutes(e.minutes);
      if (!success) {
        emit(EarnedTimeInsufficientBalance(currentData));
        await Future.delayed(const Duration(seconds: 2));
        emit(EarnedTimeLoaded(currentData));
        return;
      }

      // Lift shields
      debugPrint('🔓 Lifting shields for ${e.minutes} minutes');
      await ScreenTimeService.endSession();

      // Schedule re-lock — if fails on simulator, we still show
      // the countdown because Firestore ends_at drives the timer
      try {
        await ScreenTimeService.scheduleFreeSession(minutes: e.minutes);
      } catch (_) {
        debugPrint(
            '⚠️ scheduleFreeSession failed (simulator) — timer still runs');
        // Don't return — free session is still valid via Firestore ends_at
      }

      // Ticker will start from _onDataUpdated when Firestore stream fires
    } catch (err) {
      debugPrint('❌ Spend failed: $err');
      emit(EarnedTimeError(err.toString()));
    }
  }

  Future<void> _onFreeSessionEnd(
    EarnedTimeFreeSessionEnded e,
    Emitter<EarnedTimeState> emit,
  ) async {
    _stopTicker();
    debugPrint('🔒 Free session ended — re-locking apps');

    // Re-apply shields
    await ScreenTimeService.reApplyShields();
    await _repo.endFreeSession();

    final data = await _repo.getData();
    emit(EarnedTimeFreeSessionExpired(data));

    await Future.delayed(const Duration(seconds: 3));
    emit(EarnedTimeLoaded(data));
  }

  void _onTick(EarnedTimeTick e, Emitter<EarnedTimeState> emit) {
    final data = _getCurrentData();
    if (data == null || !data.hasFreeSession) {
      _stopTicker();
      return;
    }

    final remaining = data.activeSession!.remainingSeconds;
    if (remaining <= 0) {
      add(EarnedTimeFreeSessionEnded());
      return;
    }

    emit(EarnedTimeFreeActive(
      data: data,
      remainingSeconds: remaining,
    ));
  }

  void _emitCorrectState(EarnedTimeData data, Emitter<EarnedTimeState> emit) {
    if (data.hasFreeSession) {
      emit(EarnedTimeFreeActive(
        data: data,
        remainingSeconds: data.activeSession!.remainingSeconds,
      ));
    } else {
      emit(EarnedTimeLoaded(data));
    }
  }

  EarnedTimeData? _getCurrentData() {
    final s = state;
    if (s is EarnedTimeLoaded) return s.data;
    if (s is EarnedTimeFreeActive) return s.data;
    if (s is EarnedTimeSpending) return s.data;
    return null;
  }

  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(EarnedTimeTick()),
    );
  }

  void _stopTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  Future<void> close() async {
    await _dataSub?.cancel();
    _tickTimer?.cancel();
    return super.close();
  }
}
