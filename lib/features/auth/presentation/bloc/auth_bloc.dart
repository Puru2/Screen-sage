// lib/features/auth/presentation/bloc/auth_bloc.dart
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';

// ── Events ──────────────────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthUserChanged extends AuthEvent {
  final User? user;
  AuthUserChanged(this.user);
  @override
  List<Object?> get props => [user?.uid];
}

class AuthSignInWithGoogleRequested extends AuthEvent {}

class AuthSignInWithAppleRequested extends AuthEvent {}

class AuthSignOutRequested extends AuthEvent {}

class AuthSignUpWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignUpWithEmailRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthSignInWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  AuthSignInWithEmailRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;
  AuthPasswordResetRequested(this.email);
  @override
  List<Object?> get props => [email];
}

// ── States ──────────────────────────────────────────────────────────
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
  @override
  List<Object?> get props => [user.uid];
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {}

// ── Bloc ────────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  late final StreamSubscription<User?> _authSub;

  AuthBloc(this._repo) : super(AuthInitial()) {
    on<AuthUserChanged>(_onUserChanged);
    on<AuthSignInWithGoogleRequested>(_onSignInWithGoogle);
    on<AuthSignInWithAppleRequested>(_onSignInWithApple);
    on<AuthSignUpWithEmailRequested>(_onSignUpWithEmail);
    on<AuthSignInWithEmailRequested>(_onSignInWithEmail);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthSignOutRequested>(_onSignOut);

    // Listen to Firebase Auth state changes globally
    _authSub = _repo.authStateChanges.listen((User? user) {
      add(AuthUserChanged(user));
    });
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthSuccess(event.user!));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(
      AuthSignInWithGoogleRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final credential = await _repo.signInWithGoogle();
      if (credential == null) {
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'A Google Sign-In error occurred'));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignInWithApple(
      AuthSignInWithAppleRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final credential = await _repo.signInWithApple();
      if (credential == null) {
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'An Apple Sign-In error occurred'));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSignUpWithEmail(
      AuthSignUpWithEmailRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repo.signUpWithEmail(event.email, event.password);
      // Success will be caught by _authSub
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'Sign up failed'));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInWithEmail(
      AuthSignInWithEmailRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repo.signInWithEmail(event.email, event.password);
      // Success will be caught by _authSub
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'Sign in failed. Check your credentials.'));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onPasswordResetRequested(
      AuthPasswordResetRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repo.resetPassword(event.email);
      emit(AuthPasswordResetSent());
      emit(Unauthenticated());
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'Password reset failed'));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignOut(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _repo.signOut();
    emit(Unauthenticated());
  }

  @override
  Future<void> close() {
    _authSub.cancel();
    return super.close();
  }
}
