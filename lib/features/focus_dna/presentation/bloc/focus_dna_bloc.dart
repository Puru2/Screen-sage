import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/focus_dna.dart';
import '../../data/repositories/focus_dna_repository.dart';

abstract class FocusDNAEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FocusDNALoadRequested extends FocusDNAEvent {}

abstract class FocusDNAState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FocusDNAInitial extends FocusDNAState {}

class FocusDNALoading extends FocusDNAState {}

class FocusDNALoaded extends FocusDNAState {
  final FocusDNA dna;
  FocusDNALoaded(this.dna);
  @override
  List<Object?> get props => [dna];
}

class FocusDNAError extends FocusDNAState {
  final String message;
  FocusDNAError(this.message);
}

class FocusDNABloc extends Bloc<FocusDNAEvent, FocusDNAState> {
  FocusDNABloc(this._repo) : super(FocusDNAInitial()) {
    on<FocusDNALoadRequested>(_onLoad);
  }

  final FocusDNARepository _repo;

  Future<void> _onLoad(
    FocusDNALoadRequested e,
    Emitter<FocusDNAState> emit,
  ) async {
    emit(FocusDNALoading());
    try {
      final dna = await _repo.computeDNA();
      emit(FocusDNALoaded(dna));
    } catch (err) {
      // print('Error computing DNA: $err');
      debugPrint('❌ Error computing Focus DNA: $err');
      emit(FocusDNAError(err.toString()));
    }
  }
}
