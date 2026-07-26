import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/analytics_repository.dart';

abstract class AnalyticsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AnalyticsLoadRequested extends AnalyticsEvent {}

class AnalyticsRefreshRequested extends AnalyticsEvent {}

class AnalyticsRangeChanged extends AnalyticsEvent {
  final AnalyticsRange range;
  AnalyticsRangeChanged(this.range);
  @override
  List<Object?> get props => [range];
}

abstract class AnalyticsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState {}

class AnalyticsLoading extends AnalyticsState {}

class AnalyticsLoaded extends AnalyticsState {
  final AnalyticsSummary summary;
  AnalyticsLoaded(this.summary);
  @override
  List<Object?> get props => [summary];
}

class AnalyticsError extends AnalyticsState {
  final String message;
  AnalyticsError(this.message);
  @override
  List<Object?> get props => [message];
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc(this._repo) : super(AnalyticsInitial()) {
    on<AnalyticsLoadRequested>(_onLoad);
    on<AnalyticsRefreshRequested>(_onLoad);
    on<AnalyticsRangeChanged>(_onRangeChanged);
  }

  final AnalyticsRepository _repo;
  AnalyticsRepository get repository => _repo;
  AnalyticsRange _currentRange = AnalyticsRange.week;

  Future<void> _onLoad(AnalyticsEvent e, Emitter<AnalyticsState> emit) async {
    if (state is! AnalyticsLoaded) emit(AnalyticsLoading());
    try {
      final summary = await _repo.getSummary(range: _currentRange);
      emit(AnalyticsLoaded(summary));
    } catch (err) {
      emit(AnalyticsError(err.toString()));
    }
  }

  Future<void> _onRangeChanged(
    AnalyticsRangeChanged e,
    Emitter<AnalyticsState> emit,
  ) async {
    _currentRange = e.range;
    // Keep current data visible while loading new range
    final current =
        state is AnalyticsLoaded ? (state as AnalyticsLoaded).summary : null;
    if (current != null) emit(AnalyticsLoaded(current));
    try {
      final summary = await _repo.getSummary(range: _currentRange);
      emit(AnalyticsLoaded(summary));
    } catch (err) {
      emit(AnalyticsError(err.toString()));
    }
  }
}
