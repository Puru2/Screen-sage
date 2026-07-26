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
  final String username;
  AuthSignUpWithEmailRequested({
    required this.email,
    required this.password,
    required this.username,
  });
  @override
  List<Object?> get props => [email, password, username];
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

    _authSub = _repo.authStateChanges.listen((User? user) {
      add(AuthUserChanged(user));
    });
  }

  Future<void> _onUserChanged(
      AuthUserChanged event, Emitter<AuthState> emit) async {
    if (event.user != null) {
      // Safety net: covers app restarts, persisted sessions, and any
      // login path that didn't already call ensureUserDocument.
      await _repo.ensureUserDocument(user: event.user!);
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
      final user = credential?.user;
      if (user == null) {
        emit(Unauthenticated());
        return;
      }
      await _repo.ensureUserDocument(user: user);
      // AuthSuccess will also be emitted by _authSub via AuthUserChanged
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
      final user = credential?.user;
      if (user == null) {
        emit(Unauthenticated());
        return;
      }
      await _repo.ensureUserDocument(user: user);
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
      // Firebase Auth only ever receives email + password.
      final credential = await _repo.signUpWithEmail(
        event.email,
        event.password,
      );

      final user = credential.user;
      if (user == null) {
        emit(AuthFailure('Sign up failed'));
        emit(Unauthenticated());
        return;
      }

      // username is app-only metadata, written to Firestore, not Auth.
      await _repo.ensureUserDocument(
        user: user,
        username: event.username,
      );
      // AuthSuccess will follow via _authSub -> AuthUserChanged
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
      final credential =
          await _repo.signInWithEmail(event.email, event.password);
      final user = credential.user;
      if (user != null) {
        await _repo.ensureUserDocument(user: user);
      }
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
