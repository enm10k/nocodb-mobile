import 'package:nocodb/common/preferences.dart';

import 'package:nocodb/nocodb_sdk/client.dart';

final settings = _Settings();

class Settings {
  Settings({required this.host, required this.token, this.username});

  final String? username;
  final String host;
  final Token token;
}

const _kUsername = 'username';
const _kHost = 'host';
const _kAuthToken = 'auth_token';
const _kApiToken = 'api_token';

class _Settings {
  Preferences? prefs;
  bool get initialized => prefs != null;
  init(Preferences prefs) {
    this.prefs = prefs;
  }

  Future<void> save({
    required String host,
    required Token token,
    String? username,
  }) async {
    await clear();
    await prefs?.set(key: _kHost, value: host);
    if (username != null) {
      await prefs?.set(key: _kUsername, value: username);
    }

    switch (token) {
      case AuthToken(authToken: final authToken):
        await prefs?.set(key: _kAuthToken, value: authToken, secure: true);
      case ApiToken(apiToken: final apiToken):
        await prefs?.set(key: _kApiToken, value: apiToken, secure: true);
      default:
        throw Exception('unsupported token type: ${token.runtimeType}');
    }
  }

  Future<Settings?> get() async {
    final host = await prefs?.get<String>(key: _kHost);
    if (host == null) {
      return null;
    }

    final username = await prefs?.get<String>(key: _kUsername);
    final authToken = await prefs?.getSecure(key: _kAuthToken);
    if (authToken != null) {
      return Settings(
        username: username,
        host: host,
        token: AuthToken(authToken),
      );
    }

    final apiToken = await prefs?.getSecure(key: _kApiToken);
    if (apiToken != null) {
      return Settings(
        username: username,
        host: host,
        token: ApiToken(apiToken),
      );
    }
    return null;
  }

  Future<void> clear() async {
    await prefs?.clear();
  }
}
