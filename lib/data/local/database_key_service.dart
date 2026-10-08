import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owns the device-local database key.
///
/// The key is never written to SharedPreferences, SQLite, logs, source code,
/// backups, or the API. Android uses Keystore-backed encrypted storage, iOS
/// uses Keychain, and Windows uses the OS credential-protection implementation
/// supplied by flutter_secure_storage.
class DatabaseKeyService {
  DatabaseKeyService._();

  static final DatabaseKeyService instance = DatabaseKeyService._();

  static const _storageKey = 'doctor_app_database_key_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && _isValidKey(existing)) return existing;

    if (existing != null && existing.isNotEmpty) {
      throw StateError('The protected database key is invalid.');
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);

    await _storage.write(key: _storageKey, value: key);
    final verified = await _storage.read(key: _storageKey);
    if (verified != key) {
      throw StateError('The protected database key could not be verified.');
    }

    return key;
  }

  bool _isValidKey(String value) {
    try {
      return base64Url.decode(value).length == 32;
    } catch (_) {
      return false;
    }
  }
}
