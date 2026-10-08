import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef WindowsDatabaseCreateCallback = Future<void> Function(
  Database database,
  int version,
);

typedef WindowsDatabaseUpgradeCallback = Future<void> Function(
  Database database,
  int oldVersion,
  int newVersion,
);

/// Encrypted database entry point used only by the Windows build.
///
/// The database key is supplied before the first schema read. Startup also
/// verifies both cipher availability and database integrity. A regular
/// SQLite binary therefore fails closed instead of creating plaintext data.
class WindowsEncryptedDatabase {
  const WindowsEncryptedDatabase._();

  static Future<Database> open({
    required String fileName,
    required String password,
    required int version,
    required WindowsDatabaseCreateCallback onCreate,
    required WindowsDatabaseUpgradeCallback onUpgrade,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('The Windows database adapter requires Windows.');
    }

    sqfliteFfiInit();
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'PrivatePractices', 'Database'),
    );
    await databaseDirectory.create(recursive: true);

    final databasePath = p.join(databaseDirectory.path, fileName);
    final escapedPassword = password.replaceAll("'", "''");

    final database = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          // sqlite3 3.5.2 uses SQLite3 Multiple Ciphers. Select its
          // SQLCipher-compatible AES-256 scheme before setting the key.
          await db.execute("PRAGMA cipher = 'sqlcipher'");
          await db.execute("PRAGMA key = '$escapedPassword'");
          await db.execute('PRAGMA memory_security = ON');
          await db.execute('PRAGMA foreign_keys = ON');

          final cipher = await db.rawQuery('PRAGMA cipher');
          final selectedCipher = cipher
              .expand((row) => row.values)
              .where((value) => !_isEmptyValue(value))
              .map((value) => value.toString().trim().toLowerCase())
              .toList();
          if (!selectedCipher.contains('sqlcipher')) {
            throw StateError(
              'Encrypted SQLite is unavailable. Refusing to open medical records.',
            );
          }
        },
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      ),
    );

    try {
      // Reading sqlite_master proves that the supplied encryption key can
      // decrypt the database. The normal integrity check then validates its
      // page and schema structure; HMAC checking remains enabled by default.
      await database.rawQuery('SELECT count(*) FROM sqlite_master');
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      if (!_integrityPassed(integrity)) {
        throw StateError('Encrypted database integrity verification failed.');
      }
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  static bool _isEmptyValue(Object? value) =>
      value == null || value.toString().trim().isEmpty;

  static bool _integrityPassed(List<Map<String, Object?>> rows) {
    return rows.length == 1 &&
        rows.first.values.any(
          (value) => value?.toString().trim().toLowerCase() == 'ok',
        );
  }
}
