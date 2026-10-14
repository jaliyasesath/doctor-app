import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:doctor_app/client/pp_client_session.dart';
import 'package:doctor_app/client/pp_client_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void seed() => FlutterSecureStorage.setMockInitialValues({'pp_client_identity_session_v1': jsonEncode({
    'origin': PPClientConfig.origin.toString(), 'access': 'access', 'refresh': 'refresh',
    'expires': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String()})});
  test('401 during booking rotates then retries with the SAME booking request ID', () async {
    seed(); final bodies = <String>[]; var rotations = 0;
    final client = PPClientSession(transport: MockClient((request) async {
      if (request.url.path.endsWith('/profile')) return http.Response('{"patientAccountId":1}', 200);
      if (request.url.path.endsWith('/refresh')) {
        rotations++; return http.Response(jsonEncode({'accessToken':'new-access','refreshToken':'new-refresh',
          'expiresAt': DateTime.now().toUtc().add(const Duration(minutes:15)).toIso8601String(),
          'profile': {'patientAccountId':1}}), 200);
      }
      expect(request.url.path, '/api/client/bookings'); bodies.add(request.body);
      return bodies.length == 1 ? http.Response('{}',401) : http.Response('{"queueNo":4,"status":"Waiting"}',200);
    }));
    await client.restore();
    await client.bookDoctor(5,'c44abdd4-0fdd-4054-8925-57acd57a73c1');
    expect(rotations,1); expect(bodies.length,2); expect(bodies[0],bodies[1]); client.dispose();
  });
  test('doctor search sends location and search as encoded query, never patient profile fields', () async {
    seed();
    final client = PPClientSession(transport: MockClient((request) async {
      if (request.url.path.endsWith('/profile')) return http.Response('{"patientAccountId":1}',200);
      expect(request.url.path,'/api/client/doctors'); expect(request.url.queryParameters['search'],'Clinic & Town');
      expect(request.url.queryParameters['latitude'],'6.9'); expect(request.url.queryParameters.containsKey('mobileNumber'),false);
      expect(request.headers['Authorization'],'Bearer access'); return http.Response('{"items":[],"hasMore":false}',200);
    }));
    await client.restore(); await client.findDoctors(latitude:6.9,longitude:79.8,search:'Clinic & Town'); client.dispose();
  });
}
