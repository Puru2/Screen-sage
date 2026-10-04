import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/streak_repository.dart';

abstract class StreakEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StreakLoadRequested extends StreakEvent {}

class StreakResetRequested extends StreakEvent {}

class StreakUserChanged extends StreakEvent {
  final String? uid;

  StreakUserChanged(this.uid);

  @override
  List<Object?> get props => [uid];
}

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
    on<StreakResetRequested>(_onReset);
    on<StreakUserChanged>(_onUserChanged);
    on<StreakDataUpdated>(
      (event, emit) => emit(StreakLoaded(event.data)),
    );

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      add(StreakUserChanged(user?.uid));
    });
  }

  final StreakRepository _repo;

  StreamSubscription<StreakData>? _sub;
  late final StreamSubscription<User?> _authSub;

  Future<void> _onUserChanged(
    StreakUserChanged event,
    Emitter<StreakState> emit,
  ) async {
    // Always stop listening to the previous user's streak.
    await _sub?.cancel();
    _sub = null;

    // Logged out.
    if (event.uid == null) {
      emit(StreakInitial());
      return;
    }

    // New user.
    add(StreakLoadRequested());
  }

  Future<void> _onReset(
    StreakResetRequested event,
    Emitter<StreakState> emit,
  ) async {
    await _sub?.cancel();
    _sub = null;

    emit(StreakInitial());
  }

  Future<void> _onLoad(
    StreakLoadRequested event,
    Emitter<StreakState> emit,
  ) async {
    // Make sure an old user's listener cannot remain active.
    await _sub?.cancel();
    _sub = null;

    emit(StreakLoading());

    try {
      final data = await _repo.getData();

      emit(StreakLoaded(data));

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
    await _authSub.cancel();
    return super.close();
  }
}
