/// Thin HTTP client wrapping `package:http`.
///
/// - Attaches `Authorization: Bearer <token>` when a token is available.
/// - Handles token refresh on 401 and persists the refreshed token pair.
/// - Parses the backend error envelope into typed exceptions.
/// - Never exposes raw backend stack traces.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.onTokensRefreshed,
    this.onSessionExpired,
  })
      : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Called after a successful token refresh so the new pair can be persisted.
  final void Function(String accessToken, String refreshToken)? onTokensRefreshed;

  /// Called when refresh fails on a 401 (session truly expired/invalidated).
  final void Function()? onSessionExpired;

  String? _accessToken;
  String? _refreshToken;
  static const _requestTimeout = Duration(seconds: 15);

  void setTokens({String? access, String? refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
    if (json) headers['Content-Type'] = 'application/json';
    return headers;
  }

  /// Perform a GET request.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    var uri = _uri(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    }
    return _send(() => _http.get(uri, headers: _headers()));
  }

  Future<dynamic> post(String path, {Object? body}) => _send(
        () => _http.post(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body)),
      );

  Future<dynamic> put(String path, {Object? body}) => _send(
        () => _http.put(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body)),
      );

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers()));

  Future<dynamic> patch(String path, {Object? body}) => _send(
        () => _http.patch(_uri(path), headers: _headers(), body: body == null ? null : jsonEncode(body)),
      );

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(message: 'The request timed out. Please try again.');
    } catch (_) {
      throw NetworkException('No internet connection. Please try again.');
    }

    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        try {
          response = await request().timeout(_requestTimeout);
        } on TimeoutException {
          throw const ApiException(message: 'The request timed out. Please try again.');
        } catch (_) {
          throw NetworkException('No internet connection. Please try again.');
        }
      } else {
        onSessionExpired?.call();
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw _mapError(response);
  }

  bool _refreshing = false;
  Future<bool> _tryRefresh() async {
    if (_refreshing || _refreshToken == null) return false;
    _refreshing = true;
    try {
      final uri = _uri('${AppConstants.apiV1Prefix}/auth/refresh');
      // The refresh token travels in the JSON body, never in the URL query -
      // URLs leak into logs and history, and a refresh token renews the whole
      // session.
      final res = await _http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({'refresh_token': _refreshToken}),
          )
          .timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as JsonMap;
        final access = body['access_token'] as String?;
        final refresh = body['refresh_token'] as String?;
        if (access == null || refresh == null) return false;
        setTokens(access: access, refresh: refresh);
        onTokensRefreshed?.call(access, refresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  ApiException _mapError(http.Response response) {
    String code = '';
    String message = 'Something went wrong. Please try again.';
    Map<String, dynamic>? details;
    try {
      final body = jsonDecode(response.body) as JsonMap;
      final err = body['error'] as JsonMap?;
      code = err?['code'] as String? ?? '';
      message = err?['message'] as String? ?? message;
      details = err?['details'] as Map<String, dynamic>?;
    } catch (_) {
      // Non-JSON error page - keep the generic safe message.
    }

    if (response.statusCode == 401) {
      return UnauthorizedException(message);
    }
    if (response.statusCode >= 500) {
      return ServerException(message);
    }
    return RequestFailedException(message, code: code, statusCode: response.statusCode, details: details);
  }
}