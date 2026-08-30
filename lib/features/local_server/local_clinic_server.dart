import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../data/local/database_helper.dart';
import '../sync/services/auto_sync_service.dart';

class LocalClinicServer {
  static HttpServer? _server;
  static bool _running = false;
  static String _pairingToken = '';
  static DateTime? _pairingExpiresAt;
  static const Duration _pairingLifetime = Duration(hours: 8);

  static bool get isRunning => _running;
  static String get pairingToken => _pairingToken;
  static DateTime? get pairingExpiresAt => _pairingExpiresAt;

  static String get _today => DateTime.now().toIso8601String().split('T').first;

  static Future<void> start({int port = 8080}) async {
    if (_running) return;

    _pairingToken = _createPairingToken();
    _pairingExpiresAt = DateTime.now().toUtc().add(_pairingLifetime);

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
          SELECT COUNT(*) AS count
          FROM patients
          WHERE date(queue_date) = date(?)
            AND queue_status = ?
          ''',
          [_today, status],
        );

        return (result.first['count'] as int?) ?? 0;
      }

      final previousPending = await db.rawQuery(
        '''
        SELECT COUNT(*) AS count
        FROM patients
        WHERE date(queue_date) < date(?)
          AND (queue_status = ? OR queue_status = ?)
        ''',
        [_today, 'Waiting', 'Serving'],
      );

      return _json({
        'waiting': await countStatus('Waiting'),
        'serving': await countStatus('Serving'),
        'completed': await countStatus('Completed'),
        'skipped': await countStatus('Skipped'),
        'previousPending': (previousPending.first['count'] as int?) ?? 0,
      });
    });

    router.get('/api/Patients/waiting', (Request request) async {
      return _json(
        await _todayPatientsByStatuses(['Waiting', 'Serving']),
      );
    });

    router.get('/api/Patients/skipped', (Request request) async {
      return _json(await _todayPatientsByStatuses(['Skipped']));
    });

    router.get('/api/Patients/completed', (Request request) async {
      return _json(await _todayPatientsByStatuses(['Completed']));
    });

    router.get('/api/Patients/previous-pending', (Request request) async {
      return _json(await _previousPendingPatients());
    });

    router.post('/api/Patients', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      final result = await db.rawQuery(
        '''
        SELECT MAX(queue_no) AS max_no
        FROM patients
        WHERE date(queue_date) = date(?)
        ''',
        [_today],
      );

      final nextQueueNo = ((result.first['max_no'] as num?)?.toInt() ?? 0) + 1;

      final localId = await DatabaseHelper.instance.insertPatient({
        'doctor_id': data['doctorId'] ?? 0,
        'patient_name': data['patientName']?.toString() ?? '',
        'patient_age':
            data['age']?.toString() ?? data['patientAge']?.toString() ?? '',
        'patient_gender': data['gender']?.toString() ??
            data['patientGender']?.toString() ??
            '',
        'phone_number': data['phoneNumber']?.toString() ?? '',
        'address': data['address']?.toString() ?? '',
        'notes': data['notes']?.toString() ?? '',
        'allergies': data['allergies']?.toString() ?? '',
        'chronic_diseases': data['chronicDiseases']?.toString() ?? '',
        'important_alerts': data['importantAlerts']?.toString() ?? '',
        'queue_status': 'Waiting',
        'queue_no': nextQueueNo,
        'queue_date': _today,
        'sync_status': 'pending',
      });
      unawaited(AutoSyncService.syncPendingChanges());

      return _json({
        'success': true,
        'offline': true,
        'localServer': true,
        'id': localId,
        'serverId': localId,
        'patientCode': 'OFF-$localId',
        'queueNo': nextQueueNo,
        'queueStatus': 'Waiting',
        'queueDate': _today,
      });
    });

    router.post('/api/Patients/<id|[0-9]+>/move-to-today',
        (Request request, String id) async {
      final patientId = int.tryParse(id) ?? 0;
      await DatabaseHelper.instance.moveQueuePatientToToday(patientId);
      unawaited(AutoSyncService.syncPendingChanges());

      final patient = await DatabaseHelper.instance.getPatientById(patientId);

      if (patient == null) {
        return _json(
          {'success': false, 'message': 'Patient not found'},
          statusCode: 404,
        );
      }

      return _json({
        'success': true,
        'patientId': patientId,
        'queueNo': patient['queue_no'],
        'queueStatus': patient['queue_status'],
        'queueDate': patient['queue_date'],
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
        'message': 'Patient removed from queue',
        'patientId': int.tryParse(id) ?? 0,
      });
    });

    router.post('/api/Patients/<id|[0-9]+>/serving',
        (Request request, String id) async {
      await _updatePatientStatus(id, 'Serving');
      return _json({
        'success': true,
        'message': 'Patient now serving',
        'patientId': int.tryParse(id) ?? 0,
      });
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_pairingMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, '0.0.0.0', port);
    _running = true;

    print(
      'Local Clinic Server running on '
      '${_server!.address.address}:$port',
    );
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _running = false;
    _pairingToken = '';
    _pairingExpiresAt = null;
  }

  static Future<List<Map<String, dynamic>>> _todayPatientsByStatuses(
    List<String> statuses,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(statuses.length, '?').join(', ');

    final patients = await db.rawQuery(
      '''
      SELECT *
      FROM patients
      WHERE date(queue_date) = date(?)
        AND queue_status IN ($placeholders)
      ORDER BY queue_no ASC, id ASC
      ''',
      [_today, ...statuses],
    );

    return patients.map(_mapPatient).toList();
  }

  static Future<List<Map<String, dynamic>>> _previousPendingPatients() async {
    final db = await DatabaseHelper.instance.database;

    final patients = await db.rawQuery(
      '''
      SELECT *
      FROM patients
      WHERE date(queue_date) < date(?)
        AND (queue_status = ? OR queue_status = ?)
      ORDER BY queue_date ASC, queue_no ASC, id ASC
      ''',
      [_today, 'Waiting', 'Serving'],
    );

    return patients.map(_mapPatient).toList();
  }

  static Map<String, dynamic> _mapPatient(Map<String, dynamic> patient) {
    return {
      'id': patient['id'],
      'patientCode': patient['server_id'] != null
          ? 'P${patient['server_id']}'
          : 'OFF-${patient['id']}',
      'queueNo': patient['queue_no'] ?? patient['id'],
      'queueStatus': patient['queue_status'] ?? 'Waiting',
      'queueDate': patient['queue_date'],
      'patientName': patient['patient_name'] ?? '',
      'patientAge': patient['patient_age'] ?? '',
      'patientGender': patient['patient_gender'] ?? '',
      'phoneNumber': patient['phone_number'] ?? '',
      'address': patient['address'] ?? '',
      'notes': patient['notes'] ?? '',
      'allergies': patient['allergies'] ?? '',
      'chronicDiseases': patient['chronic_diseases'] ?? '',
      'importantAlerts': patient['important_alerts'] ?? '',
    };
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
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [patientId],
    );
    unawaited(AutoSyncService.syncPendingChanges());
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
          headers: {...response.headers, ..._corsHeaders()},
        );
      };
    };
  }

  static Map<String, String> _corsHeaders() {
    return {
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
          'Content-Type, Authorization, X-Clinic-Pairing-Token',
    };
  }

  static Middleware _pairingMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return innerHandler(request);
        }
        final supplied = request.headers['x-clinic-pairing-token'] ?? '';
        final expired = _pairingExpiresAt == null ||
            !_pairingExpiresAt!.isAfter(DateTime.now().toUtc());
        if (expired || _pairingToken.isEmpty || supplied != _pairingToken) {
          return _json({
            'success': false,
            'message': 'Clinic pairing authentication is required.',
            'code': 'HOTSPOT_PAIRING_REQUIRED',
          }, statusCode: 401);
        }
        return innerHandler(request);
      };
    };
  }

  static String _createPairingToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
