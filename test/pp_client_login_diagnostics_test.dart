import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/client/pp_client_session.dart';

void main() {
  test('native diagnostics exclude messages and details', () {
    final error = PlatformException(
      code: 'keychain_error',
      message: 'private-email@example.com',
      details: {'idToken': 'secret-token'},
    );
    expect(PPClientSession.diagnosticReference(error, 'google-authenticate'),
        'PPLOGIN-1 / google-authenticate / keychain_error');
  });

  test('arbitrary native code content is not displayed', () {
    final error = PlatformException(code: 'secret token / private-email@example.com');
    expect(PPClientSession.diagnosticReference(error, 'session-restore'),
        'PPLOGIN-1 / session-restore / platform_error');
  });

  test('unexpected errors expose type only', () {
    expect(PPClientSession.diagnosticReference(
        StateError('secret-token'), 'api-google'),
        'PPLOGIN-1 / api-google / StateError');
  });
}
