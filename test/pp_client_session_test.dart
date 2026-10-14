import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:doctor_app/client/pp_client_config.dart';
import 'package:doctor_app/client/pp_client_session.dart';

const key = 'pp_client_identity_session_v1';
Map<String, dynamic> get profile => {'patientAccountId': 7, 'fullName': 'Test Patient', 'email': 'test@example.com'};
void seed({bool expired = false, String? origin}) {
  FlutterSecureStorage.setMockInitialValues({key: jsonEncode({
    'origin': origin ?? PPClientConfig.origin.toString(), 'access': 'old-access', 'refresh': 'old-refresh',
    'expires': DateTime.now().toUtc().add(Duration(minutes: expired ? -2 : 10)).toIso8601String(),
  })});
}
http.Response tokens() => http.Response(jsonEncode({'accessToken': 'next-access',
  'refreshToken': 'next-refresh', 'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
  'profile': profile}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('expired restored session rotates once across concurrent profile requests', () async {
    seed(expired: true); var refreshes = 0;
    final session = PPClientSession(transport: MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) {
        refreshes++; expect(jsonDecode(request.body)['refreshToken'], 'old-refresh'); return tokens();
      }
      expect(request.headers['Authorization'], 'Bearer next-access');
      return http.Response(jsonEncode(profile), 200);
    }));
    await session.restore();
    await Future.wait([session.reloadProfile(), session.reloadProfile()]);
    expect(refreshes, 1); expect(session.profile!['patientAccountId'], 7);
    session.dispose();
  });
  test('revoked refresh removes local credentials', () async {
    seed(expired: true);
    final session = PPClientSession(transport: MockClient((_) async => http.Response('{}', 401)));
    await expectLater(session.restore(), throwsA(isA<PPClientError>()));
    expect(session.signedIn, false);
    expect(await const FlutterSecureStorage().read(key: key), isNull);
    session.dispose();
  });
  test('stored credentials for another API are never sent', () async {
    seed(origin: 'https://other.example'); var requests = 0;
    final session = PPClientSession(transport: MockClient((_) async { requests++; return http.Response('{}', 200); }));
    await session.restore(); expect(requests, 0); expect(session.signedIn, false);
    session.dispose();
  });
  test('successful logout revokes before clearing local session', () async {
    seed(); var revoked = false;
    final session = PPClientSession(transport: MockClient((request) async {
      if (request.url.path.endsWith('/logout')) {
        expect(request.method, 'POST'); revoked = true; return http.Response('', 204);
      }
      return http.Response(jsonEncode(profile), 200);
    }));
    await session.restore(); await session.logout();
    expect(revoked, true); expect(session.signedIn, false);
    session.dispose();
  });
  test('failed server logout retains session for explicit retry', () async {
    seed();
    final session = PPClientSession(transport: MockClient((request) async => request.url.path.endsWith('/logout')
      ? http.Response('internal detail', 503) : http.Response(jsonEncode(profile), 200)));
    await session.restore(); await expectLater(session.logout(), throwsA(isA<PPClientError>()));
    expect(session.signedIn, true); session.dispose();
  });
}
