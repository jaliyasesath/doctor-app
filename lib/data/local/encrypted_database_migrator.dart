import 'dart:io';

import 'package:sqflite_sqlcipher/sqflite.dart';

typedef DatabaseCreateCallback = Future<void> Function(
  Database database,
  int version,
);

typedef DatabaseUpgradeCallback = Future<void> Function(
  Database database,
  int oldVersion,
  int newVersion,
);

/// Opens an encrypted SQLCipher database and performs a one-time, verified
/// migration when an existing installation still has a plaintext SQLite DB.
///
/// The original file remains available until schema creation, row copying,
/// per-table row-count checks, and SQLCipher integrity checks all succeed.
class EncryptedDatabaseMigrator {
  const EncryptedDatabaseMigrator._();

  static Future<Database> openOrMigrate({
    required String path,
    required String password,
    required int version,
    required DatabaseCreateCallback onCreate,
    required DatabaseUpgradeCallback onUpgrade,
  }) async {
    await _recoverInterruptedMigration(path);

    final file = File(path);
    if (!await file.exists()) {
      return _openEncrypted(
        path: path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
    }

    // Do not probe a known plaintext SQLite file with an SQLCipher key. Some
    // platform builds can spend a long time trying cipher compatibility modes
    // before returning "file is not a database". The SQLite header gives us a
    // deterministic, non-destructive routing decision.
    if (await _hasPlaintextHeader(path)) {
      return _migratePlaintext(
        path: path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
    }

    final encrypted = await _tryOpenEncrypted(
      path: path,
      password: password,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
    if (encrypted != null) {
      final backupPath = '$path.plaintext-backup';
      final backup = File(backupPath);
      if (await backup.exists()) {
        final comparison = await _compareWithPlaintextBackup(
          encrypted,
          backupPath,
        );

        if (comparison == null) {
          await encrypted.close();
          throw StateError(
            'The database recovery copy could not be verified. '
            'No recovery file was deleted.',
          );
        }

        if (!comparison) {
          // A previous build may have created a new empty encrypted DB after
          // the plaintext file was moved. Prefer the verified recovery copy.
          await encrypted.close();
          await file.delete();
          await _deleteSidecars(path);
          await backup.rename(path);
          return _migratePlaintext(
            path: path,
            password: password,
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
          );
        }
      }

      // Complete cleanup if a prior run activated and verified the encrypted
      // DB but the OS interrupted deletion of the plaintext recovery copy.
      await _removeActivatedMigrationFiles(path);
      return encrypted;
    }

    if (!await _isReadablePlaintext(path)) {
      throw StateError(
        'The local database cannot be unlocked. Restore the protected '
        'database key or sign in and recover fully synced cloud data.',
      );
    }

    return _migratePlaintext(
      path: path,
      password: password,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  static Future<Database> _openEncrypted({
    required String path,
    required String password,
    required int version,
    required DatabaseCreateCallback onCreate,
    required DatabaseUpgradeCallback onUpgrade,
  }) {
    return openDatabase(
      path,
      password: password,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  static Future<Database?> _tryOpenEncrypted({
    required String path,
    required String password,
    required int version,
    required DatabaseCreateCallback onCreate,
    required DatabaseUpgradeCallback onUpgrade,
  }) async {
    Database? database;
    try {
      database = await _openEncrypted(
        path: path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
      await database.rawQuery('SELECT count(*) FROM sqlite_master');
      return database;
    } catch (_) {
      await database?.close();
      return null;
    }
  }

  static Future<bool> _isReadablePlaintext(String path) async {
    Database? database;
    try {
      database = await openDatabase(path, readOnly: true);
      await database.rawQuery('SELECT count(*) FROM sqlite_master');
      return true;
    } catch (_) {
      return false;
    } finally {
      await database?.close();
    }
  }

  static Future<bool> _hasPlaintextHeader(String path) async {
    final handle = await File(path).open();
    try {
      final header = await handle.read(16);
      const sqliteHeader = <int>[
        0x53,
        0x51,
        0x4c,
        0x69,
        0x74,
        0x65,
        0x20,
        0x66,
        0x6f,
        0x72,
        0x6d,
        0x61,
        0x74,
        0x20,
        0x33,
        0x00,
      ];
      if (header.length != sqliteHeader.length) return false;
      for (var index = 0; index < sqliteHeader.length; index++) {
        if (header[index] != sqliteHeader[index]) return false;
      }
      return true;
    } finally {
      await handle.close();
    }
  }

  static Future<Database> _migratePlaintext({
    required String path,
    required String password,
    required int version,
    required DatabaseCreateCallback onCreate,
    required DatabaseUpgradeCallback onUpgrade,
  }) async {
    final backupPath = '$path.plaintext-backup';
    final encryptedPath = '$path.encrypted-new';
    final originalFile = File(path);
    final backupFile = File(backupPath);
    final encryptedFile = File(encryptedPath);

    if (await backupFile.exists() || await encryptedFile.exists()) {
      throw StateError(
        'A previous secure database migration needs recovery. The app will '
        'not overwrite recovery files.',
      );
    }

    await _checkpointPlaintext(path);
    await originalFile.rename(backupPath);
    await _deleteSidecars(path);

    Database? source;
    Database? target;
    Database? activated;
    try {
      // Upgrade the plaintext source to the current schema before cloning it.
      source = await openDatabase(
        backupPath,
        version: version,
        onUpgrade: onUpgrade,
        singleInstance: false,
      );
      await source.execute('PRAGMA wal_checkpoint(TRUNCATE)');

      // Use SQLCipher's supported export path instead of rebuilding every
      // table/index/trigger in Dart. Replaying sqlite_master SQL can fail on
      // real-world databases whose schema contains internal ordering or
      // compatibility details, even though the source database is healthy.
      await _exportWithSqlCipher(
        source: source,
        encryptedPath: encryptedPath,
        password: password,
      );

      target = await openDatabase(
        encryptedPath,
        password: password,
        singleInstance: false,
      );
      await _verifyDatabase(source, target);

      await source.close();
      source = null;
      await target.close();
      target = null;

      await encryptedFile.rename(path);
      await _deleteSidecars(encryptedPath);

      // Re-open the activated file through the exact production path before
      // removing the plaintext recovery copy. This catches key/plugin/open
      // incompatibilities while the original database is still recoverable.
      final activatedDatabase = await _openEncrypted(
        path: path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
      activated = activatedDatabase;
      await activatedDatabase.rawQuery('SELECT count(*) FROM sqlite_master');

      // The plaintext recovery copy is removed only after export, row-count
      // verification, cipher integrity verification, activation and a final
      // production re-open all succeed.
      await backupFile.delete();
      await _deleteSidecars(backupPath);

      return activatedDatabase;
    } catch (_) {
      await source?.close();
      await target?.close();
      await activated?.close();

      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
      await _deleteSidecars(encryptedPath);

      if (await backupFile.exists()) {
        // If activation already happened, [path] is the failed encrypted
        // candidate. Remove only that candidate, then restore the untouched
        // plaintext recovery copy.
        if (await originalFile.exists()) {
          await originalFile.delete();
          await _deleteSidecars(path);
        }
        await backupFile.rename(path);
      }
      rethrow;
    }
  }

  static Future<void> _exportWithSqlCipher({
    required Database source,
    required String encryptedPath,
    required String password,
  }) async {
    final escapedPath = _sqlLiteral(encryptedPath);
    final escapedPassword = _sqlLiteral(password);
    var attached = false;

    try {
      await source.execute(
        "ATTACH DATABASE '$escapedPath' AS encrypted KEY '$escapedPassword'",
      );
      attached = true;

      // sqlcipher_export is invoked through sqlite3_exec semantics. Some
      // Android bridges report an error when it is stepped as a row-returning
      // rawQuery even though the export itself is valid.
      await source.execute("SELECT sqlcipher_export('encrypted')");

      final sourceVersion = Sqflite.firstIntValue(
            await source.rawQuery('PRAGMA user_version'),
          ) ??
          0;
      await source.execute(
        'PRAGMA encrypted.user_version = $sourceVersion',
      );
    } finally {
      if (attached) {
        await source.execute('DETACH DATABASE encrypted');
      }
    }
  }

  static String _sqlLiteral(String value) => value.replaceAll("'", "''");

  static Future<void> _verifyDatabase(
    Database source,
    Database target,
  ) async {
    final integrity = await target.rawQuery('PRAGMA cipher_integrity_check');
    if (integrity.isNotEmpty) {
      final values = integrity.expand((row) => row.values).toList();
      if (values.any((value) => value?.toString().toLowerCase() != 'ok')) {
        throw StateError('Encrypted database integrity verification failed.');
      }
    }

    final tables = await source.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ''');

    for (final table in tables) {
      final name = table['name']?.toString();
      if (name == null || name.isEmpty) continue;

      final sourceCount = Sqflite.firstIntValue(
            await source.rawQuery('SELECT COUNT(*) FROM "$name"'),
          ) ??
          0;
      final targetCount = Sqflite.firstIntValue(
            await target.rawQuery('SELECT COUNT(*) FROM "$name"'),
          ) ??
          0;
      if (sourceCount != targetCount) {
        throw StateError('Database migration verification failed for $name.');
      }
    }
  }

  static Future<bool?> _compareWithPlaintextBackup(
    Database encrypted,
    String backupPath,
  ) async {
    Database? backup;
    try {
      backup = await openDatabase(
        backupPath,
        readOnly: true,
        singleInstance: false,
      );
      final tables = await backup.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      ''');

      for (final table in tables) {
        final name = table['name']?.toString();
        if (name == null || name.isEmpty) continue;

        final backupCount = Sqflite.firstIntValue(
              await backup.rawQuery('SELECT COUNT(*) FROM "$name"'),
            ) ??
            0;
        final encryptedCount = Sqflite.firstIntValue(
              await encrypted.rawQuery('SELECT COUNT(*) FROM "$name"'),
            ) ??
            0;
        if (backupCount != encryptedCount) return false;
      }
      return true;
    } catch (_) {
      return null;
    } finally {
      await backup?.close();
    }
  }

  static Future<void> _checkpointPlaintext(String path) async {
    Database? database;
    try {
      database = await openDatabase(path);
      await database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await database?.close();
    }
  }

  static Future<void> _deleteSidecars(String path) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  static Future<void> _recoverInterruptedMigration(String path) async {
    final original = File(path);
    final backup = File('$path.plaintext-backup');
    final encryptedCandidate = File('$path.encrypted-new');

    final originalExists = await original.exists();
    final backupExists = await backup.exists();
    final candidateExists = await encryptedCandidate.exists();

    // The process stopped after moving the plaintext DB but before activating
    // the verified encrypted copy. Restore the only authoritative database.
    if (!originalExists && backupExists) {
      if (candidateExists) {
        await encryptedCandidate.delete();
        await _deleteSidecars(encryptedCandidate.path);
      }
      await backup.rename(path);
      return;
    }

    // A candidate is never authoritative while the original DB is present.
    // It is safe to remove and recreate it from the original on the next run.
    if (originalExists && candidateExists) {
      await encryptedCandidate.delete();
      await _deleteSidecars(encryptedCandidate.path);
    }

    // No file may be silently replaced when recovery state is incomplete.
    if (!originalExists && candidateExists) {
      throw StateError(
        'Secure database migration recovery requires the original database.',
      );
    }
  }

  static Future<void> _removeActivatedMigrationFiles(String path) async {
    final backupPath = '$path.plaintext-backup';
    final backup = File(backupPath);
    if (await backup.exists()) await backup.delete();
    await _deleteSidecars(backupPath);

    final encryptedPath = '$path.encrypted-new';
    final encrypted = File(encryptedPath);
    if (await encrypted.exists()) await encrypted.delete();
    await _deleteSidecars(encryptedPath);
  }
}
