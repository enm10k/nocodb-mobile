import 'dart:io';

import 'package:flutter/foundation.dart';

import 'logger.dart';
import 'preferences.dart';
import '../nocodb_sdk/client.dart';

final settings = Settings();

class RememberedData {
  final String host;
  final Token token;

  RememberedData(this.host, this.token);
}

class Settings {
  Preferences? prefs;
  bool get initialized => prefs != null;
  init(Preferences prefs) {
    this.prefs = prefs;
  }

  Future<void> remember({
    required String host,
    required Token token,
    String? email,
  }) async {
    await clear();
    await prefs?.set(key: _apiBaseUrl, value: host);
    await prefs?.set(
      key: _rememberMe,
      value: true,
    );

    switch (token) {
      case AuthToken(authToken: final authToken):
        await prefs?.set(key: _authToken, value: authToken, secure: true);
        break;
      case ApiToken(apiToken: final apiToken):
        await prefs?.set(key: _apiToken, value: apiToken, secure: true);
        break;
      default:
        throw Exception('unsupported token type: ${token.runtimeType}');
    }
  }

  Future<RememberedData?> getRemembered() async {
    final host = await apiBaseUrl;
    if (host == null) {
      return null;
    }

    final authToken = await prefs?.getSecure(key: _authToken);
    if (authToken != null) {
      return RememberedData(host, AuthToken(authToken));
    }

    final apiToken = await prefs?.getSecure(key: _apiToken);
    if (apiToken != null) {
      logger.finest('B');
      return RememberedData(host, ApiToken(apiToken));
    }
    return null;
  }

  static const _authToken = 'authToken';

  static const _apiToken = 'apiToken';

  static const _email = 'email';
  Future<String?> get email async => await prefs?.get(key: _email);
  Future<void> setEmail(String v) async => await prefs?.set(
        key: _email,
        value: v,
      );

  static const _apiBaseUrl = 'apiBaseUrl';
  Future<String?> get apiBaseUrl async {
    final v = await prefs?.get<String>(key: _apiBaseUrl);
    if (v == null && !kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return v;
  }

  static const _rememberMe = 'rememberMe';

  Future<void> clear() async {
    await prefs?.clear();
  }
}
