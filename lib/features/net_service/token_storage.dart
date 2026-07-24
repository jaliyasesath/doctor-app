import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _deviceIdKey = 'auth_device_id';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> _readAndMigrate(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) return secureValue;

    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue != null && legacyValue.isNotEmpty) {
      await _secureStorage.write(key: key, value: legacyValue);
      await prefs.remove(key);
      return legacyValue;
    }
    return null;
  }

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  static Future<void> saveTokenPair({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _tokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static Future<String?> getToken() async {
    return _readAndMigrate(_tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _readAndMigrate(_refreshTokenKey);
  }

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final id = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
