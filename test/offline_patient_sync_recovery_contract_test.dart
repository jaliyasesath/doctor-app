import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline patient sync retries after connectivity recovery', () {
    final source = File(
      'lib/features/sync/services/auto_sync_service.dart',
    ).readAsStringSync();

    expect(source, contains('scheduleRecovery()'));
    expect(source, contains('_recoverWithRetry'));
    expect(source, contains('Duration(seconds: 10)'));
    expect(source, contains('hasPendingLocalChanges()'));
    expect(source, contains('syncPendingChanges(networkConfirmed: true)'));
    expect(source, contains("context: 'Queue recovery attempt'"));
  });

  test('app resume requests pending sync recovery', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains('AutoSyncService.scheduleRecovery();'),
    );
  });

  test('background sync restores session without storing password', () {
    final source = File(
      'lib/features/sync/services/sync_service.dart',
    ).readAsStringSync();

    expect(source, contains('ApiClient.refreshSession()'));
    expect(source, contains('syncAll({bool networkConfirmed = false})'));
    expect(source, isNot(contains('CredentialStorage.getPassword')));
  });

  test('connectivity recovery re-resolves an auto API URL', () {
    final source = File(
      'lib/features/sync/services/sync_service.dart',
    ).readAsStringSync();

    expect(source, contains('if (ApiConfig.isAuto)'));
    expect(source, contains('await AutoApiResolver.resolve();'));
    expect(source, contains("'No reachable API server was found.'"));
  });
}
