/// Auth repository: HTTP calls for register/login/logout/refresh/forgot.
///
/// On a successful login/register the tokens are pushed back into the
/// shared `ApiClient` so every subsequent request is authenticated.
library;

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthSession> register(String name, String email, String password) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return _apply(_parseSession(data));
  }

  Future<AuthSession> login(String email, String password) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/login',
      body: {'email': email, 'password': password},
    );
    return _apply(_parseSession(data));
  }

  Future<AuthSession> loginWithFirebase(String idToken) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/auth/firebase',
      body: {'id_token': idToken},
    );
    return _apply(_parseSession(data));
  }

  Future<void> logout() async => _api.post('${AppConstants.apiV1Prefix}/auth/logout');

  /// Permanently delete the signed-in account and all of its data.
  Future<void> deleteAccount() async {
    await _api.delete('${AppConstants.apiV1Prefix}/auth/me');
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('${AppConstants.apiV1Prefix}/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _api.post(
      '${AppConstants.apiV1Prefix}/auth/reset-password',
      body: {'token': token, 'new_password': newPassword},
    );
  }

  Future<AuthSession> demoLogin() async {
    final data = await _api.post('${AppConstants.apiV1Prefix}/auth/demo');
    return _apply(_parseSession(data));
  }

  /// Fetch the currently authenticated user (used to restore a session).
  Future<User> currentUser() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/auth/status');
    return User.fromJson((data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
  }

  /// Restore a previously persisted session (tokens only; user is re-fetched).
  void restoreTokens({required String access, required String refresh}) {
    _api.setTokens(access: access, refresh: refresh);
  }

  void clearSession() => _api.clearTokens();

  AuthSession _apply(AuthSession session) {
    _api.setTokens(access: session.accessToken, refresh: session.refreshToken);
    return session;
  }

  AuthSession _parseSession(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
}