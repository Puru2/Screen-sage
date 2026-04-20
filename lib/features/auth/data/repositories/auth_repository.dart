// lib/features/auth/data/repositories/auth_repository.dart

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

ValueNotifier<AuthRepository> authRepositoryProvider =
    ValueNotifier(AuthRepository());

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Maintain a single instance for the repository lifecycle.
  // No scopes defined here anymore.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ─────────────────────────────────────────────────────────────
  // Streams & Getters
  // ─────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─────────────────────────────────────────────────────────────
  // Google Sign In (LATEST 7.x.x APPROACH)
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint("Starting Google Sign-In flow...");

      // Force account picker by clearing any previous cached sessions
      await _googleSignIn.signOut();

      GoogleSignInAccount? googleUser;

      // The new standard: check if the platform supports the new authenticate() flow
      if (_googleSignIn.supportsAuthenticate()) {
        debugPrint("Platform supports authenticate(). Proceeding...");
        googleUser = await _googleSignIn.authenticate();
      }

      if (googleUser == null) {
        debugPrint("User canceled Google Sign-In.");
        return null;
      }

      debugPrint("Google Auth successful. Fetching tokens...");

      // Retrieve the authentication tokens required by Firebase
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create the Firebase credential
      // Note: We need both accessToken and idToken for a robust login.
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      debugPrint("Authenticating with Firebase...");
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Apple Sign In (Correct Nonce Handling)
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Email & Password
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // update username
  Future<void> updateUserName(String username) async {
    await currentUser?.updateDisplayName(username);
  }

  // delete account
  Future<void> deleteAccount(String email, String password) async {
    AuthCredential credential =
        EmailAuthProvider.credential(email: email.trim(), password: password);
    await currentUser?.reauthenticateWithCredential(credential);
    await currentUser?.delete();
    await _auth.signOut();
  }

  // reset current password
  Future<void> resetCurrentPassword(
      String newPassword, String oldPassword, String email) async {
    AuthCredential credential = EmailAuthProvider.credential(
        email: email.trim(), password: oldPassword);
    await currentUser?.reauthenticateWithCredential(credential);
    await currentUser?.updatePassword(newPassword);
  }

  // ─────────────────────────────────────────────────────────────
  // Sign Out
  // ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    // Disconnect revokes the Google scopes and clears the session completely
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting Google Sign-In: $e");
    }
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────
  // Apple Nonce Helpers
  // ─────────────────────────────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
