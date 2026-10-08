import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app lock preserves tokens while complete sign-out revokes them', () {
    final source = File(
      'lib/features/auth/data/api_auth_service.dart',
    ).readAsStringSync();

    final lockStart = source.indexOf('Future<void> lockApp()');
    final logoutStart = source.indexOf('Future<void> logout()');
    expect(lockStart, greaterThanOrEqualTo(0));
    expect(logoutStart, greaterThan(lockStart));

    final lockBody = source.substring(lockStart, logoutStart);
    final logoutBody = source.substring(logoutStart);
    expect(lockBody, contains('DoctorSession.clearSession()'));
    expect(lockBody, isNot(contains('TokenStorage.clearToken()')));
    expect(lockBody, isNot(contains("'/Auth/logout'")));
    expect(logoutBody, contains("'/Auth/logout'"));
    expect(logoutBody, contains('DoctorSession.disableBiometric()'));
    expect(logoutBody, contains('TokenStorage.clearToken()'));
  });

  test('doctor and reception logout directly preserves biometric sync', () {
    for (final path in <String>[
      'lib/features/dashboard/screens/home_screen.dart',
      'lib/features/reception/screens/reception_dashboard_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ApiAuthService().lockApp()'));
      expect(source, isNot(contains('_showSessionActions')));
      expect(source, isNot(contains('_signOutCompletely')));
    }
  });
}
