import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows local records require SQLCipher and integrity verification', () {
    final source = File(
      'lib/data/local/windows_encrypted_database.dart',
    ).readAsStringSync();

    expect(source, contains("PRAGMA key ="));
    expect(source, contains("PRAGMA cipher = 'sqlcipher'"));
    expect(source, contains('PRAGMA memory_security = ON'));
    expect(source, contains('SELECT count(*) FROM sqlite_master'));
    expect(source, contains('PRAGMA integrity_check'));
    expect(source, contains('Refusing to open medical records'));
  });

  test('database helper routes Windows without changing mobile migration', () {
    final source = File(
      'lib/data/local/database_helper.dart',
    ).readAsStringSync();

    expect(source, contains('if (Platform.isWindows)'));
    expect(source, contains('WindowsEncryptedDatabase.open'));
    expect(source, contains('EncryptedDatabaseMigrator.openOrMigrate'));
  });

  test('desktop dashboard uses permanent workspace and guards camera scanning', () {
  final homeSource = File(
    'lib/features/dashboard/screens/home_screen.dart',
  ).readAsStringSync();

  final workspaceSource = File(
    'lib/core/widgets/desktop_workspace_screen.dart',
  ).readAsStringSync();

  expect(homeSource, contains('width >= 1000'));
  expect(homeSource, contains('DesktopWorkspaceScreen('));
  expect(
    homeSource,
    contains("Platform.isWindows && title == 'Scan Prescription'"),
  );

  expect(workspaceSource, contains('class DesktopWorkspaceScreen'));
  expect(workspaceSource, contains('Navigator('));
  expect(workspaceSource, contains('Prescription History'));
  expect(workspaceSource, contains('Patient History'));
});

  test('pubspec selects the Dart 3.11-compatible encrypted native build', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('sqflite_common_ffi:'));
    expect(source, contains('source: sqlite3mc'));
  });

  test('Windows runner uses the production product name', () {
    final runner = File('windows/runner/main.cpp').readAsStringSync();
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();

    expect(runner, contains('Private Practices'));
    expect(cmake, contains('BINARY_NAME "PrivatePractices"'));
  });
}
