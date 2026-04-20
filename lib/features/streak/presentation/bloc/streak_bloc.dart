import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/streak_repository.dart';

abstract class StreakEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StreakLoadRequested extends StreakEvent {}

class StreakDataUpdated extends StreakEvent {
  final StreakData data;
  StreakDataUpdated(this.data);
  @override
  List<Object?> get props => [data];
}

abstract class StreakState extends Equatable {
  @override
  List<Object?> get props => [];
}

class StreakInitial extends StreakState {}

class StreakLoading extends StreakState {}

class StreakLoaded extends StreakState {
  final StreakData data;
  StreakLoaded(this.data);
  @override
  List<Object?> get props => [data];
}

class StreakBloc extends Bloc<StreakEvent, StreakState> {
  StreakBloc(this._repo) : super(StreakInitial()) {
    on<StreakLoadRequested>(_onLoad);
    on<StreakDataUpdated>((e, emit) => emit(StreakLoaded(e.data)));
  }

  final StreakRepository _repo;
  StreamSubscription<StreakData>? _sub;

  Future<void> _onLoad(
    StreakLoadRequested e,
    Emitter<StreakState> emit,
  ) async {
    emit(StreakLoading());
    try {
      final data = await _repo.getData();
      emit(StreakLoaded(data));
      // Real-time updates
      await _sub?.cancel();
      _sub = _repo.watchData().listen(
            (data) => add(StreakDataUpdated(data)),
          );
    } catch (err) {
      emit(StreakLoaded(StreakData.empty()));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
