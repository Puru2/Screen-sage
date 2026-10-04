// lib/features/auth/data/repositories/auth_repository.dart

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

ValueNotifier<AuthRepository> authRepositoryProvider =
    ValueNotifier(AuthRepository());

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ─────────────────────────────────────────────────────────────
  // Streams & Getters
  // ─────────────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─────────────────────────────────────────────────────────────
  // Google Sign In
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint("Starting Google Sign-In flow...");
      await _googleSignIn.signOut();

      GoogleSignInAccount? googleUser;
      if (_googleSignIn.supportsAuthenticate()) {
        googleUser = await _googleSignIn.authenticate();
      }

      if (googleUser == null) {
        debugPrint("User canceled Google Sign-In.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Apple Sign In
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
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Email & Password — Firebase Auth only needs email + password
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

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateUserName(String username) async {
    await currentUser?.updateDisplayName(username);
  }

  Future<void> deleteAccount(String email, String password) async {
    AuthCredential credential =
        EmailAuthProvider.credential(email: email.trim(), password: password);
    await currentUser?.reauthenticateWithCredential(credential);
    await currentUser?.delete();
    await _auth.signOut();
  }

  Future<void> resetCurrentPassword(
      String newPassword, String oldPassword, String email) async {
    AuthCredential credential = EmailAuthProvider.credential(
        email: email.trim(), password: oldPassword);
    await currentUser?.reauthenticateWithCredential(credential);
    await currentUser?.updatePassword(newPassword);
  }

  // ─────────────────────────────────────────────────────────────
  // Firestore user profile — created ONCE, only after Auth succeeds
  // username is app metadata only — never touches FirebaseAuth calls
  // ─────────────────────────────────────────────────────────────
  Future<void> ensureUserDocument({
    required User user,
    String? username,
  }) async {
    final userRef = _db.collection('users').doc(user.uid);
    final snap = await userRef.get();

    if (snap.exists) return; // already created — never overwrite

    await userRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'username': username?.trim() ?? (user.displayName ?? ''),
      'createdAt': FieldValue.serverTimestamp(),
      'isPremium': false,
      'premiumProductId': null,
      'premiumValidTill': null,
      'premiumUpdatedAt': null,
      'isInTrial': false,
      'trialEndsAt': null
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Sign Out
  // ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
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
