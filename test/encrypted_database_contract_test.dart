import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile database uses a protected SQLCipher key and safe migration', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final databaseHelper =
        File('lib/data/local/database_helper.dart').readAsStringSync();
    final keyService =
        File('lib/data/local/database_key_service.dart').readAsStringSync();
    final migrator = File('lib/data/local/encrypted_database_migrator.dart')
        .readAsStringSync();

    expect(pubspec, contains('sqflite_sqlcipher: ^3.4.1'));
    expect(pubspec, isNot(contains('\n  sqflite:')));
    expect(
      databaseHelper,
      contains('DatabaseKeyService.instance.getOrCreateKey'),
    );
    expect(databaseHelper, contains('_databaseOpening'));
    expect(databaseHelper, contains('identical(_databaseOpening, opening)'));
    expect(databaseHelper, contains('EncryptedDatabaseMigrator.openOrMigrate'));
    expect(keyService, contains('Random.secure()'));
    expect(keyService, contains('FlutterSecureStorage'));
    expect(migrator, contains('.plaintext-backup'));
    expect(migrator, contains('PRAGMA cipher_integrity_check'));
    expect(migrator, contains('sourceCount != targetCount'));
    expect(migrator, contains('await backupFile.delete()'));
    expect(migrator, contains('_recoverInterruptedMigration(path)'));
    expect(migrator, contains('_removeActivatedMigrationFiles(path)'));
    expect(migrator, contains('_compareWithPlaintextBackup'));
    expect(migrator, contains('_hasPlaintextHeader(path)'));
    expect(migrator, contains('const sqliteHeader = <int>['));
    expect(migrator, contains("sqlcipher_export('encrypted')"));
    expect(
      migrator,
      contains('source.execute("SELECT sqlcipher_export'),
    );
    expect(
      migrator,
      isNot(contains('source.rawQuery("SELECT sqlcipher_export')),
    );
    expect(migrator, contains('ATTACH DATABASE'));
    expect(migrator, contains('DETACH DATABASE encrypted'));
    expect(migrator, contains('await activatedDatabase.rawQuery'));
    expect(
      migrator,
      contains('No recovery file was deleted'),
    );
    expect(
      migrator,
      contains('await backup.rename(path)'),
    );
    expect(
      migrator,
      contains('Secure database migration recovery requires'),
    );
  });

  test('offline authentication stores only an expiring password verifier', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final credentials = File(
      'lib/features/auth/data/credential_storage.dart',
    ).readAsStringSync();
    final sync = File(
      'lib/features/sync/services/sync_service.dart',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('crypto: ^3.0.6'));
    expect(credentials, contains('static Uint8List _pbkdf2'));
    expect(credentials, contains('Hmac(sha256'));
    expect(credentials, contains('saveVerifier'));
    expect(credentials, contains('_iterations = 210000'));
    expect(credentials, contains('Duration(days: 30)'));
    expect(credentials, contains('_maximumFailures = 5'));
    expect(credentials, isNot(contains('value: password')));
    expect(sync, isNot(contains('CredentialStorage.getPassword')));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules'));
  });

  test('biometric profile loading does not require password decryption', () {
    final session =
        File('lib/features/auth/data/doctor_session.dart').readAsStringSync();
    final login =
        File('lib/features/auth/screens/login_screen.dart').readAsStringSync();

    final methodStart = session.indexOf('getLastDoctorForBiometric()');
    final methodEnd = session.indexOf('static Future<bool> isLoggedIn()');
    final biometricProfile = session.substring(methodStart, methodEnd);

    expect(biometricProfile, isNot(contains('_readSecurePassword')));
    expect(login, isNot(contains('CredentialStorage.getPassword(email)')));
    expect(
      login,
      contains("TimeoutException('database_migration')"),
    );
    expect(
      login,
      contains('Securing local medical records...'),
    );
    expect(login, contains('DBM-01'));
  });
}
