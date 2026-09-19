import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:harvest/core/platform/secret_store.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A failure from the Harvest server, in its own shape
/// (`{ error: { code, message, details } }`, [[Sync-API]]).
class ApiException implements Exception {
  const ApiException(this.code, this.status, [this.message, this.details]);

  /// `validation_failed`, `unauthorized`, `forbidden`, `conflict`,
  /// `rate_limited`, `unavailable`, `internal` — or `offline` when the
  /// server was never reached.
  final String code;
  final int status;
  final String? message;
  final Object? details;

  bool get offline => code == 'offline';

  @override
  String toString() =>
      'ApiException($code, $status${message == null ? '' : ': $message'})';
}

/// The access token lives in memory only; the refresh token lives in
/// the keystore ([[Accounts]]).
class TokenStore {
  TokenStore(this._secrets);

  static const refreshKey = 'account.refreshToken';

  final SecretStore _secrets;
  String? access;

  Future<String?> refresh() => _secrets.read(refreshKey);
  Future<void> setRefresh(String? token) => _secrets.write(refreshKey, token);

  Future<void> clear() async {
    access = null;
    await setRefresh(null);
  }
}

/// A JSON call to the Harvest server, with the session kept alive.
///
/// An expired access token is refreshed once and the call retried. Only
/// one refresh runs at a time: a refresh token used twice revokes its
/// whole family on the server, which would sign out every device on it
/// ([[Accounts]] AC4).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? client,
    this.onSignedOut,
  }) : _client = client ?? http.Client();

  /// Up to the host, e.g. `https://harvest.example.org`.
  final Uri Function() baseUrl;
  final TokenStore tokens;
  final http.Client _client;

  /// Called when the session is gone for good (refresh refused).
  final void Function()? onSignedOut;

  Future<void>? _refreshing;

  Future<Map<String, Object?>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, Object?>> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<Map<String, Object?>> patch(String path, Object? body) =>
      _send('PATCH', path, body: body);

  Future<Map<String, Object?>> delete(String path, [Object? body]) =>
      _send('DELETE', path, body: body);

  /// A call that must not carry or refresh a session: sign-in, sign-up,
  /// the emailed links.
  Future<Map<String, Object?>> postAnonymous(String path, Object? body) =>
      _send('POST', path, body: body, authenticated: false);

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool retried = false,
  }) async {
    if (authenticated && tokens.access == null && !retried) {
      await _refreshOnce();
    }
    final response = await _raw(
      method,
      path,
      body: body,
      query: query,
      bearer: authenticated ? tokens.access : null,
    );
    if (response.statusCode == 401 && authenticated && !retried) {
      await _refreshOnce();
      return _send(
        method,
        path,
        body: body,
        query: query,
        retried: true,
      );
    }
    return _decode(response);
  }

  Future<void> _refreshOnce() => _refreshing ??= _refresh().whenComplete(
    () => _refreshing = null,
  );

  Future<void> _refresh() async {
    final token = await tokens.refresh();
    if (token == null) {
      throw const ApiException('unauthorized', 401, 'Signed out');
    }
    final response = await _raw(
      'POST',
      '/v1/auth/refresh',
      body: {'refreshToken': token},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      await tokens.clear();
      onSignedOut?.call();
      throw const ApiException('unauthorized', 401, 'Session ended');
    }
    final json = _decode(response);
    await adopt(json);
  }

  /// Takes the tokens out of an auth answer (login, register, refresh).
  Future<void> adopt(Map<String, Object?> auth) async {
    tokens.access = auth['accessToken'] as String?;
    final refresh = auth['refreshToken'];
    if (refresh is String) await tokens.setRefresh(refresh);
  }

  Future<http.Response> _raw(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? bearer,
  }) async {
    final base = baseUrl();
    final url = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}$path',
      queryParameters: query,
    );
    final request = http.Request(method, url)
      ..headers['accept'] = 'application/json';
    if (bearer != null) request.headers['authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 30)),
      );
    } on SocketException {
      throw const ApiException('offline', 0);
    } on TimeoutException {
      throw const ApiException('offline', 0);
    } on http.ClientException {
      throw const ApiException('offline', 0);
    }
  }

  static Map<String, Object?> _decode(http.Response response) {
    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json is Map<String, Object?> ? json : const {};
    }
    final error = json is Map<String, Object?> ? json['error'] : null;
    if (error is Map<String, Object?>) {
      throw ApiException(
        error['code'] as String? ?? 'internal',
        response.statusCode,
        error['message'] as String?,
        error['details'],
      );
    }
    throw ApiException('internal', response.statusCode);
  }
}

/// The signed-in account, as `/v1/me` describes it.
@immutable
class Me {
  const Me({
    required this.id,
    required this.email,
    required this.syncSalt,
    this.displayName,
    this.verifiedAt,
  });

  factory Me.fromJson(Map<String, Object?> json) => Me(
    id: json['id']! as String,
    email: json['email']! as String,
    syncSalt: json['syncSalt']! as String,
    displayName: json['displayName'] as String?,
    verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
  );

  final String id;
  final String email;
  final String? displayName;
  final DateTime? verifiedAt;

  /// The public half of the private tier's key ([[Sync-API]]).
  final String syncSalt;

  bool get verified => verifiedAt != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'syncSalt': syncSalt,
    'displayName': displayName,
    'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
  };
}
