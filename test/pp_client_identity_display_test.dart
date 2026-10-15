import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:doctor_app/client/pp_client_identity_display.dart';
import 'package:doctor_app/client/pp_client_config.dart';
import 'package:doctor_app/client/pp_client_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('doctor names receive one display prefix', () {
    expect(ppClientDoctorName(' Pathum '), 'Dr. Pathum');
    expect(ppClientDoctorName('Dr. Perera'), 'Dr. Perera');
    expect(ppClientDoctorName('dr Perera'), 'Dr. Perera');
    expect(ppClientDoctorName('Dr.Perera'), 'Dr. Perera');
    expect(ppClientDoctorName('Drake'), 'Dr. Drake');
    expect(ppClientDoctorName(null), 'Doctor');
  });
  test('profile photo accepts HTTPS only', () {
    expect(ppClientPhotoUrl('https://lh3.googleusercontent.com/photo'), isNotNull);
    expect(ppClientPhotoUrl('http://example.com/photo'), isNull);
    expect(ppClientPhotoUrl('https://user:password@example.com/photo'), isNull);
    expect(ppClientPhotoUrl(null), isNull);
  });
  for (final account in [7, 8]) {
    test('photo cache matches authenticated account $account', () async {
      final origin = PPClientConfig.origin.toString();
      FlutterSecureStorage.setMockInitialValues({
        'pp_client_identity_session_v1': jsonEncode({
          'origin': origin, 'access': 'access', 'refresh': 'refresh',
          'expires': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
        }),
        'pp_client_google_photo_v1': jsonEncode({
          'origin': origin, 'patientAccountId': 7,
          'url': 'https://lh3.googleusercontent.com/photo',
        }),
      });
      final session = PPClientSession(transport: MockClient((request) async =>
        request.url.path.endsWith('/logout') ? http.Response('', 204) :
          http.Response(jsonEncode({'patientAccountId': account, 'fullName': 'Patient'}), 200)));
      await session.restore();
      expect(session.googlePhotoUrl,
          account == 7 ? 'https://lh3.googleusercontent.com/photo' : null);
      await session.logout();
      expect(session.googlePhotoUrl, isNull);
      expect(await const FlutterSecureStorage().read(key: 'pp_client_google_photo_v1'), isNull);
      session.dispose();
    });
  }
}
