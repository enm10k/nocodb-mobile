import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  late SharedPreferences _prefs;
  late FlutterSecureStorage _secureStorage;

  load() async {
    _prefs = await SharedPreferences.getInstance();
    const aOptions = AndroidOptions(encryptedSharedPreferences: true);
    _secureStorage = const FlutterSecureStorage(
      aOptions: aOptions,
    );
  }

  clear() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }

  Future<T?> get<T>({
    required String key,
  }) async {
    dynamic v;
    switch (T) {
      case const (String):
        v = _prefs.getString(key);
      case const (int):
        v = _prefs.getInt(key);
      case const (bool):
        v = _prefs.getBool(key);
      case const (double):
        v = _prefs.getDouble(key);
      case const (List<String>):
        v = _prefs.getStringList(key);
      default:
        throw Exception('unsupported type: ${v.runtimeType}');
    }

    if (v == null) {
      return null;
    } else if (v.runtimeType == T) {
      return v;
    } else {
      throw UnsupportedError(
        'expected: $T, got: ${v.runtimeType}',
      );
    }
  }

  Future<String?> getSecure({
    required String key,
  }) async =>
      await _secureStorage.read(key: key);

  Future<void> set({
    required String key,
    required dynamic value,
    bool secure = false,
  }) async {
    if (value == null) {
      return;
    }

    if (secure) {
      switch (value.runtimeType) {
        case const (String):
          await _secureStorage.write(key: key, value: value);
        default:
          throw Exception('unsupported type. key: $key');
      }
    } else {
      switch (value.runtimeType) {
        case const (String):
          await _prefs.setString(key, value);
        case const (int):
          await _prefs.setInt(key, value);
        case const (bool):
          await _prefs.setBool(key, value);
        case const (double):
          await _prefs.setDouble(key, value);
        case const (List<String>):
          await _prefs.setStringList(key, value);
        default:
          throw Exception('unsupported type. key: $key, value: $value');
      }
    }
  }
}
