import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../data/local/database_helper.dart';

class LocalClinicServer {
  static HttpServer? _server;
  static bool _running = false;

  static bool get isRunning => _running;

  static Future<void> start({int port = 8080}) async {
    if (_running) return;

    final router = Router();

    router.get('/api/Health', (Request request) {
      return _json({
        'success': true,
        'message': 'Local Clinic Server OK',
        'mode': 'local',
      });
    });
    router.get('/api/Patients/summary', (Request request) async {
  final db = await DatabaseHelper.instance.database;

  Future<int> countStatus(String status) async {
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM patients
      WHERE queue_status = ?
      ''',
      [status],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  return _json({
    'waiting': await countStatus('Waiting'),
    'serving': await countStatus('Now Serving'),
    'completed': await countStatus('Completed'),
    'skipped': await countStatus('Skipped'),
  });
});

    router.get('/api/Patients/waiting', (Request request) async {
      return _json(await _patientsByStatus('Waiting'));
    });

    router.get('/api/Patients/skipped', (Request request) async {
      return _json(await _patientsByStatus('Skipped'));
    });

    router.get('/api/Patients/completed', (Request request) async {
  return _json(await _patientsByStatus('Completed'));
});

    router.post('/api/Patients', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DatabaseHelper.instance.database;

final today = DateTime.now()
    .toIso8601String()
    .split('T')
    .first;

final result = await db.rawQuery(
  '''
  SELECT MAX(queue_no) as max_no
  FROM patients
  WHERE queue_date = ?
  ''',
  [today],
);

final lastQueue =
    (result.first['max_no'] as int?) ?? 0;

final newQueueNo = lastQueue + 1;

      final localId = await DatabaseHelper.instance.insertPatient({
        'doctor_id': 0,
        'patient_name': data['patientName']?.toString() ?? '',
        'patient_age': data['age']?.toString() ??
            data['patientAge']?.toString() ??
            '',
        'patient_gender': data['gender']?.toString() ??
            data['patientGender']?.toString() ??
            '',
        'phone_number': data['phoneNumber']?.toString() ?? '',
        'address': data['address']?.toString() ?? '',
        'notes': data['notes']?.toString() ?? '',
        'queue_status': 'Waiting',
'queue_no': newQueueNo,
'queue_date': today,
        'sync_status': 'pending',
      });

      return _json({
        'success': true,
        'offline': true,
        'localServer': true,
        'serverId': localId,
        'patientCode': 'OFF-$localId',
        'queueNo': newQueueNo,
        'queueStatus': 'Waiting',
      });
    });

    router.post('/api/Patients/<id|[0-9]+>/complete',
        (Request request, String id) async {
      await _updatePatientStatus(id, 'Completed');

      return _json({
        'success': true,
        'message': 'Patient completed',
        'patientId': int.tryParse(id) ?? 0,
      });
    });

    router.post('/api/Patients/<id|[0-9]+>/skip',
        (Request request, String id) async {
      await _updatePatientStatus(id, 'Skipped');

      return _json({
        'success': true,
        'message': 'Patient skipped',
        'patientId': int.tryParse(id) ?? 0,
      });
    });

    router.post('/api/Patients/<id|[0-9]+>/serving',
    (Request request, String id) async {

  await _updatePatientStatus(id, 'Now Serving');

  return _json({
    'success': true,
    'message': 'Patient now serving',
    'patientId': int.tryParse(id) ?? 0,
  });
});

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(
      handler,
      '0.0.0.0',
      port,
    );

    _running = true;

    print('Local Clinic Server running on ${_server!.address.address}:$port');
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _running = false;
  }

  static Future<List<Map<String, dynamic>>> _patientsByStatus(
    String status,
  ) async {
    final db = await DatabaseHelper.instance.database;

    final patients = await db.query(
      'patients',
      where: 'queue_status = ?',
      whereArgs: [status],
      orderBy: 'id ASC',
    );

    return patients.map((p) {
      return {
        'id': p['id'],
        'patientCode': p['server_id'] != null
            ? 'P${p['server_id']}'
            : 'OFF-${p['id']}',
        'queueNo': p['queue_no'] ?? p['id'],
        'queueStatus': p['queue_status'] ?? status,
        'patientName': p['patient_name'] ?? '',
        'patientAge': p['patient_age'] ?? '',
        'patientGender': p['patient_gender'] ?? '',
        'phoneNumber': p['phone_number'] ?? '',
        'address': p['address'] ?? '',
        'notes': p['notes'] ?? '',
      };
    }).toList();
  }

  static Future<void> _updatePatientStatus(
    String id,
    String status,
  ) async {
    final patientId = int.tryParse(id) ?? 0;
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'patients',
      {
        'queue_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }

  static Response _json(dynamic data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }

        final response = await innerHandler(request);

        return response.change(
          headers: {
            ...response.headers,
            ..._corsHeaders(),
          },
        );
      };
    };
  }

  static Map<String, String> _corsHeaders() {
    return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
    };
  }
}