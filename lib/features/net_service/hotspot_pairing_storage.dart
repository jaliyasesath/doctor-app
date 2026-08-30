import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class HotspotPairingStorage {
  static const _urlKey = 'hotspot_pairing_url';
  static const _tokenKey = 'hotspot_pairing_token';
  static const _expiryKey = 'hotspot_pairing_expiry';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> save({required String url, required String token,
      required DateTime expiresAt}) async {
    await _storage.write(key: _urlKey, value: url);
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiryKey,
        value: expiresAt.toUtc().toIso8601String());
  }

  static Future<bool> restore() async {
    final url = await _storage.read(key: _urlKey);
    final token = await _storage.read(key: _tokenKey);
    final expiry = DateTime.tryParse(
      await _storage.read(key: _expiryKey) ?? '',
    )?.toUtc();
    if (url == null || token == null || expiry == null ||
        !expiry.isAfter(DateTime.now().toUtc())) {
      await clear();
      return false;
    }
    ApiConfig.setHotspotBaseUrl(url);
    ApiConfig.setHotspotPairingToken(token, expiresAt: expiry);
    return true;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiryKey);
    ApiConfig.clearHotspotPairing();
  }
}
