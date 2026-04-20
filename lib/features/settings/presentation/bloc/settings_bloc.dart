import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/settings_repository.dart';

abstract class SettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsLoadRequested extends SettingsEvent {}

class SettingsUpdated extends SettingsEvent {
  final UserSettings settings;
  SettingsUpdated(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SettingsSaveRequested extends SettingsEvent {
  final UserSettings settings;
  SettingsSaveRequested(this.settings);
  @override
  List<Object?> get props => [settings];
}

abstract class SettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final UserSettings settings;
  SettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._repo) : super(SettingsInitial()) {
    on<SettingsLoadRequested>(_onLoad);
    on<SettingsUpdated>((e, emit) => emit(SettingsLoaded(e.settings)));
    on<SettingsSaveRequested>(_onSave);
  }

  final SettingsRepository _repo;
  StreamSubscription<UserSettings>? _sub;

  Future<void> _onLoad(
    SettingsLoadRequested e,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());
    final settings = await _repo.getSettings();
    emit(SettingsLoaded(settings));
    await _sub?.cancel();
    _sub = _repo.watchSettings().listen(
          (s) => add(SettingsUpdated(s)),
        );
  }

  Future<void> _onSave(
    SettingsSaveRequested e,
    Emitter<SettingsState> emit,
  ) async {
    await _repo.saveSettings(e.settings);
    emit(SettingsLoaded(e.settings));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
