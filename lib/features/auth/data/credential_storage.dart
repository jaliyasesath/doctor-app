import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(String email) =>
      'offline_credential_${base64Url.encode(utf8.encode(email.trim().toLowerCase()))}';

  static Future<void> savePassword(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return;
    await _storage.write(key: _key(email), value: password);
  }

  static Future<String?> getPassword(String email) async {
    if (email.trim().isEmpty) return null;
    return _storage.read(key: _key(email));
  }

  static Future<bool> matches(String email, String candidate) async {
    final stored = await getPassword(email);
    if (stored == null || stored.length != candidate.length) return false;

    var difference = 0;
    for (var i = 0; i < stored.length; i++) {
      difference |= stored.codeUnitAt(i) ^ candidate.codeUnitAt(i);
    }
    return difference == 0;
  }
}
