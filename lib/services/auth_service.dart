import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';

/// Logged-in user and access token, kept in memory only.
class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final User user;
  final String accessToken;
}

enum AuthFailure { invalidCredentials, other }

/// Thrown by [AuthService.login] when the login fails.
class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException($failure)';
}

/// Demo login with DummyJSON.
class AuthService {
  AuthService(this._client);

  final http.Client _client;

  static final Uri _loginUri = Uri.parse('https://dummyjson.com/auth/login');

  /// Throws [AuthException].
  Future<AuthSession> login(String username, String password) async {
    final http.Response response;
    try {
      response = await _client.post(
        _loginUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
    } on Exception {
      throw const AuthException(AuthFailure.other);
    }

    // Wrong credentials return 400: seen in tests, not stated in the DummyJSON docs
    if (response.statusCode == 400) throw const AuthException(AuthFailure.invalidCredentials);
    if (response.statusCode != 200) throw const AuthException(AuthFailure.other);

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthSession(user: User.fromJson(json), accessToken: json['accessToken'] as String);
    } on FormatException {
      throw const AuthException(AuthFailure.other);
    } on TypeError {
      // A field is missing or has an unexpected type
      throw const AuthException(AuthFailure.other);
    }
  }
}
