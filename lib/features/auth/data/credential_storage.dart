import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only a one-way, device-local verifier for offline sign-in.
class CredentialStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const int _iterations = 210000;
  static const int _derivedKeyLength = 32;
  static const int _maximumFailures = 5;
  static const Duration _validity = Duration(days: 30);
  static const Duration _lockout = Duration(minutes: 15);

  static String _accountKey(String email) =>
      base64Url.encode(utf8.encode(email.trim().toLowerCase()));

  static String _key(String email, String suffix) =>
      'offline_auth_${_accountKey(email)}_$suffix';

  /// Refreshes offline access after a successful online login. The real
  /// account password is never persisted.
  static Future<void> saveVerifier(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return;

    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final verifier = _pbkdf2(password, salt);
    final expiresAt = DateTime.now().toUtc().add(_validity);

    await _storage.write(
      key: _key(email, 'salt'),
      value: base64UrlEncode(salt),
    );
    await _storage.write(
      key: _key(email, 'verifier'),
      value: base64UrlEncode(verifier),
    );
    await _storage.write(
      key: _key(email, 'expires_at'),
      value: expiresAt.toIso8601String(),
    );
    await _storage.delete(key: _key(email, 'failures'));
    await _storage.delete(key: _key(email, 'locked_until'));
    await _storage.delete(key: _legacyKey(email));
  }

  static Future<bool> matches(String email, String candidate) async {
    if (email.trim().isEmpty || candidate.isEmpty) return false;

    final now = DateTime.now().toUtc();
    final lockedUntil = DateTime.tryParse(
      await _storage.read(key: _key(email, 'locked_until')) ?? '',
    );
    if (lockedUntil != null && now.isBefore(lockedUntil)) return false;

    final expiresAt = DateTime.tryParse(
      await _storage.read(key: _key(email, 'expires_at')) ?? '',
    );
    if (expiresAt == null || !now.isBefore(expiresAt)) {
      await clear(email);
      return false;
    }

    final saltText = await _storage.read(key: _key(email, 'salt'));
    final verifierText = await _storage.read(key: _key(email, 'verifier'));
    if (saltText == null || verifierText == null) return false;

    try {
      final salt = Uint8List.fromList(base64Url.decode(saltText));
      final expected = base64Url.decode(verifierText);
      final actual = _pbkdf2(candidate, salt);
      if (_constantTimeEquals(expected, actual)) {
        await _storage.delete(key: _key(email, 'failures'));
        await _storage.delete(key: _key(email, 'locked_until'));
        return true;
      }
    } catch (_) {
      await clear(email);
      return false;
    }

    await _recordFailure(email, now);
    return false;
  }

  static Future<void> clear(String email) async {
    for (final suffix in <String>[
      'salt',
      'verifier',
      'expires_at',
      'failures',
      'locked_until',
    ]) {
      await _storage.delete(key: _key(email, suffix));
    }
    await _storage.delete(key: _legacyKey(email));
  }

  static Future<void> purgeLegacyPassword(String email) async {
    if (email.trim().isEmpty) return;
    await _storage.delete(key: _legacyKey(email));
  }

  static Future<void> _recordFailure(String email, DateTime now) async {
    final current = int.tryParse(
          await _storage.read(key: _key(email, 'failures')) ?? '',
        ) ??
        0;
    final failures = current + 1;
    if (failures >= _maximumFailures) {
      await _storage.write(
        key: _key(email, 'locked_until'),
        value: now.add(_lockout).toIso8601String(),
      );
      await _storage.delete(key: _key(email, 'failures'));
    } else {
      await _storage.write(
        key: _key(email, 'failures'),
        value: failures.toString(),
      );
    }
  }

  static Uint8List _pbkdf2(String password, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final output = BytesBuilder(copy: false);
    var blockIndex = 1;

    while (output.length < _derivedKeyLength) {
      final counter = ByteData(4)..setUint32(0, blockIndex);
      var u = hmac.convert(<int>[
        ...salt,
        ...counter.buffer.asUint8List(),
      ]).bytes;
      final result = Uint8List.fromList(u);
      for (var iteration = 1; iteration < _iterations; iteration++) {
        u = hmac.convert(u).bytes;
        for (var index = 0; index < result.length; index++) {
          result[index] ^= u[index];
        }
      }
      output.add(result);
      blockIndex++;
    }

    return Uint8List.fromList(
      output.toBytes().take(_derivedKeyLength).toList(growable: false),
    );
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static String _legacyKey(String email) =>
      'offline_credential_${_accountKey(email)}';
}
