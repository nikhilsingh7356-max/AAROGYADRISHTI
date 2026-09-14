/// Lightweight local persistence.
///
/// - Secure storage (flutter_secure_storage) holds the JWT tokens.
/// - SharedPreferences holds small cache/metadata (current user id, has
///   non-supersede, profile cache, demo marker). We never store sensitive
///   health values in plaintext prefs.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();

  static const _secure = FlutterSecureStorage();
  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  // --- Secure tokens --------------------------------------------------------
  Future<void> saveTokens({String? access, String? refresh}) async {
    if (access != null) await _secure.write(key: 'access_token', value: access);
    if (refresh != null) await _secure.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> get accessToken => _secure.read(key: 'access_token');
  Future<String?> get refreshToken => _secure.read(key: 'refresh_token');

  Future<void> clearTokens() async {
    await _secure.delete(key: 'access_token');
    await _secure.delete(key: 'refresh_token');
  }

  // --- Plain preferences ----------------------------------------------------
  Future<void> setString(String key, String value) async {
    final sp = await _sp;
    await sp.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final sp = await _sp;
    return sp.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    final sp = await _sp;
    await sp.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final sp = await _sp;
    return sp.getBool(key);
  }

  Future<void> remove(String key) async {
    final sp = await _sp;
    await sp.remove(key);
  }

  Future<void> setInt(String key, int value) async {
    final sp = await _sp;
    await sp.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final sp = await _sp;
    return sp.getInt(key);
  }
}