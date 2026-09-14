/// Root auth/providers - the `AuthProvider` change notifier.
///
/// Responsibilities:
/// - hold the authenticated session,
/// - persist / restore tokens via StorageService,
/// - drive register / login / logout / demo access.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/app_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/storage_service.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository, {required StorageService storage}) : _storage = storage {
    restoreSession();
  }

  final AuthRepository _repository;
  final StorageService _storage;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _lastError;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get lastError => _lastError;

  bool _restored = false;
  Future<void> restoreSession() async {
    if (_restored) return;
    _restored = true;
    final access = await _storage.accessToken;
    final refresh = await _storage.refreshToken;
    if (access != null && refresh != null) {
      _repository.restoreTokens(access: access, refresh: refresh);
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
    if (_status == AuthStatus.authenticated && _user == null) {
      await _refreshUser();
    }
  }

  /// Re-fetch the signed-in user for a restored session (tokens alone are not
  /// enough - `/auth/status` is the source of truth for `user`).
  Future<void> _refreshUser() async {
    try {
      _user = await _repository.currentUser();
      notifyListeners();
    } on UnauthorizedException {
      // Stored tokens are no longer valid: clear the local session.
      await _storage.clearTokens();
      _repository.clearSession();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (_) {
      // Offline / transient: keep the session; the user is re-fetched later.
    }
  }

  Future<Null> _applySession(AuthSession session) async {
    _user = session.user;
    _status = AuthStatus.authenticated;
    await _storage.saveTokens(access: session.accessToken, refresh: session.refreshToken);
    notifyListeners();
    return null;
  }

  Future<Null> register(String name, String email, String password) async {
    _lastError = null;
    try {
      final session = await _repository.register(name, email, password);
      await _applySession(session);
    } catch (e) {
      _lastError = _friendly(e);
      rethrow;
    }
    return null;
  }

  Future<Null> login(String email, String password) async {
    _lastError = null;
    try {
      final session = await _repository.login(email, password);
      await _applySession(session);
    } catch (e) {
      _lastError = _friendly(e);
      rethrow;
    }
    return null;
  }

  Future<Null> loginWithGoogle() async {
    _lastError = null;
    try {
      final googleAccount = await _googleSignIn.authenticate();
      final googleIdToken = googleAccount.authentication.idToken;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleIdToken,
      );
      final credentialResult = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = credentialResult.user;
      final firebaseIdToken = await firebaseUser?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw StateError('Firebase did not return an ID token.');
      }
      final session = await _repository.loginWithFirebase(firebaseIdToken);
      await _applySession(session);
    } on GoogleSignInException catch (e) {
      _lastError = _googleSignInMessage(e);
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _lastError = 'Google sign-in failed (${e.code}). Please try again.';
      rethrow;
    } on PlatformException catch (e) {
      _lastError = 'Google sign-in failed (${e.code}). Please try again.';
      rethrow;
    } catch (e) {
      _lastError = _friendly(e);
      rethrow;
    }
    return null;
  }

  String _googleSignInMessage(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was cancelled.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google sign-in isn\'t configured. Add this app\'s SHA-1 fingerprint '
            'in Firebase Console, then try again.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in isn\'t available on this device yet. Try again later.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is unavailable right now. Please try again.',
      GoogleSignInExceptionCode.userMismatch =>
        'A different Google account is already signed in. Sign out and try again.',
      GoogleSignInExceptionCode.unknownError =>
        (e.description?.isNotEmpty ?? false)
            ? e.description!
            : 'Google sign-in failed. Please try again.',
    };
  }

  Future<Null> loginWithDemo() async {
    _lastError = null;
    try {
      final session = await _repository.demoLogin();
      await _applySession(session);
    } catch (e) {
      _lastError = _friendly(e);
      rethrow;
    }
    return null;
  }

  Future<Null> logout() async {
    final userId = _user?.id;
    try {
      await _repository.logout();
    } catch (_) {
      // Server logout is best-effort; local logout always succeeds.
    }
    await _storage.clearTokens();
    if (userId != null) {
      // Clear this user's onboarding cache so it can't leak across accounts
      // on a shared device.
      await _storage.remove('${AppConstants.keyOnboardingCompleted}_$userId');
    }
    await firebase_auth.FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    _repository.clearSession();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return null;
  }

  String _friendly(Object e) {
    if (e is UnauthorizedException) return 'Incorrect email or password.';
    if (e is RequestFailedException) return e.message;
    if (e is NetworkException) return 'No internet connection. Please try again.';
    if (e is ServerException) return 'Our servers are busy. Please try again shortly.';
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please try again.';
  }
}