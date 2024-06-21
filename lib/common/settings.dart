import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nocodb/common/preferences.dart';

final settings = Settings();

class Settings {
  Preferences? prefs;
  bool get initialized => prefs != null;
  init(Preferences prefs) {
    this.prefs = prefs;
  }

  static const _authToken = 'authToken';
  Future<String?> get authToken async =>
      await prefs?.getSecure(key: _authToken);

  Future<void> setAuthToken(String v) async =>
      await prefs?.set(key: _authToken, value: v, secure: true);

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

  Future<void> setApiBaseUrl(String v) async =>
      await prefs?.set(key: _apiBaseUrl, value: v);

  static const _rememberMe = 'rememberMe';
  Future<bool> get rememberMe async =>
      await prefs?.get<bool>(key: _rememberMe) ?? false;
  Future<void> setRememberMe(bool v) async => await prefs?.set(
        key: _rememberMe,
        value: v,
      );

  Future<void> clear() async {
    await prefs?.clear();
  }
}
