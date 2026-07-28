import 'dart:convert';

import '../../net_service/authenticated_http.dart' as http;

import '../../../core/errors/api_error_classifier.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/offline_fallback_policy.dart';
import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../net_service/api_config.dart';
import '../../net_service/token_storage.dart';
import 'package:sqflite/sqflite.dart';

class ApiPatientService {
  Future<Map<String, dynamic>> getQueueSummary() async {
    try {
      final token = await _getToken();

      final response = await http
          .get(
            _uri('/Patients/summary'),
            headers: _headers(token ?? ''),
          )
          .timeout(const Duration(seconds: 8));

      if (_isSuccess(response)) {
        final data = Map<String, dynamic>.from(
          jsonDecode(response.body),
        );

        return {
          'waiting': data['waiting'] ?? 0,
          'serving': data['serving'] ?? 0,
          'completed': data['completed'] ?? 0,
          'skipped': data['skipped'] ?? 0,
        };
      }

      _throwForResponse(response);
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);

      // ====================================
      // LOCAL SQLITE FALLBACK
      // ====================================

      final db = await DatabaseHelper.instance.database;
      final doctorId = await DoctorSession.getActiveDoctorIdForData();
      final today = DateTime.now().toIso8601String().split('T').first;

      if (doctorId == null) {
        return {'waiting': 0, 'serving': 0, 'completed': 0, 'skipped': 0};
      }

      final waiting = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
        SELECT COUNT(*) FROM patients
        WHERE doctor_id = ? AND date(queue_date) = date(?)
          AND queue_status = 'Waiting'
        ''',
              [doctorId, today],
            ),
          ) ??
          0;

      final serving = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
        SELECT COUNT(*) FROM patients
        WHERE doctor_id = ? AND date(queue_date) = date(?)
          AND queue_status = 'Serving'
        ''',
              [doctorId, today],
            ),
          ) ??
          0;

      final completed = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
        SELECT COUNT(*) FROM patients
        WHERE doctor_id = ? AND date(queue_date) = date(?)
          AND queue_status = 'Completed'
        ''',
              [doctorId, today],
            ),
          ) ??
          0;

      final skipped = Sqflite.firstIntValue(
            await db.rawQuery(
              '''
        SELECT COUNT(*) FROM patients
        WHERE doctor_id = ? AND date(queue_date) = date(?)
          AND queue_status = 'Skipped'
        ''',
              [doctorId, today],
            ),
          ) ??
          0;

      return {
        'waiting': waiting,
        'serving': serving,
        'completed': completed,
        'skipped': skipped,
      };
    }
  }

  Future<String?> _getToken() async {
    return TokenStorage.getToken();
  }

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) {
    final baseUrl = ApiConfig.baseUrl;

    if (baseUrl.trim().isEmpty) {
      throw const AppException(
        message: 'API base URL is empty.',
        userMessage: 'The app is currently in offline mode.',
        code: 'OFFLINE_MODE',
        kind: AppErrorKind.configuration,
      );
    }

    return Uri.parse('$baseUrl$path');
  }

  bool _isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Never _throwForResponse(http.Response response) {
    throw ApiErrorClassifier.fromHttpResponse(
      statusCode: response.statusCode,
      responseBody: response.body,
      headers: response.headers,
    );
  }

  Future<void> _cacheQueuePatients(List<dynamic> patients) async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    if (doctorId == null || patients.isEmpty) return;

    await DatabaseHelper.instance.cacheQueuePatientsFromServer(
      doctorId: doctorId,
      patients: patients,
    );
  }

  Future<List<dynamic>> getPatients({
    int page = 1,
    int pageSize = 100,
    String? updatedAfter,
  }) async {
    final token = await _getToken();

    final query = '/Patients?page=$page&pageSize=$pageSize'
        '${updatedAfter != null ? '&updatedAfter=$updatedAfter' : ''}';

    final response = await http
        .get(
          _uri(query),
          headers: _headers(token ?? ''),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['data'] != null) {
        return decoded['data'] as List<dynamic>;
      }

      return decoded as List<dynamic>;
    }

    _throwForResponse(response);
  }

  Future<Map<String, dynamic>> getPatientById(int id) async {
    final token = await _getToken();

    final response = await http
        .get(_uri('/Patients/$id'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwForResponse(response);
  }

  Future<List<dynamic>> searchPatients(
    String term, {
    int page = 1,
    int pageSize = 100,
  }) async {
    final token = await _getToken();

    final encodedTerm = Uri.encodeQueryComponent(term);

    final response = await http
        .get(
          _uri(
            '/Patients/search?term=$encodedTerm&page=$page&pageSize=$pageSize',
          ),
          headers: _headers(token ?? ''),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['data'] != null) {
        return decoded['data'] as List<dynamic>;
      }

      return decoded as List<dynamic>;
    }

    _throwForResponse(response);
  }

  Future<void> deletePatient(int id, int expectedVersion) async {
    final token = await _getToken();

    final response = await http
        .delete(
          _uri('/Patients/$id?expectedVersion=$expectedVersion'),
          headers: _headers(token ?? ''),
        )
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response)) {
      _throwForResponse(response);
    }
  }

  Future<Map<String, dynamic>> addPatient({
    required String name,
    required String age,
    required String gender,
    required String phone,
    required String address,
    required String notes,
    required String allergies,
    required String chronicDiseases,
    required String importantAlerts,
  }) async {
    try {
      final token = await _getToken();

      final response = await http
          .post(
            _uri('/Patients'),
            headers: _headers(token ?? ''),
            body: jsonEncode({
              'patientName': name,
              'age': int.tryParse(age) ?? 0,
              'gender': gender,
              'phoneNumber': phone,
              'address': address,
              'notes': notes,
              'allergies': allergies,
              'chronicDiseases': chronicDiseases,
              'importantAlerts': importantAlerts,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (_isSuccess(response)) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      _throwForResponse(response);
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);
      final doctorId = await DoctorSession.getActiveDoctorIdForData() ?? 0;

      final localId = await DatabaseHelper.instance.insertPatient({
        'doctor_id': doctorId,
        'patient_name': name,
        'patient_age': age,
        'patient_gender': gender,
        'phone_number': phone,
        'address': address,
        'notes': notes,
        'queue_status': 'Waiting',
        'sync_status': 'pending',
        'allergies': allergies,
        'chronic_diseases': chronicDiseases,
        'important_alerts': importantAlerts,
      });

      return {
        'success': true,
        'offline': true,
        'localId': localId,
        'patientCode': 'OFF-$localId',
        'queueNo': localId,
        'queueStatus': 'Waiting',
      };
    }
  }

  Future<Map<String, dynamic>> updatePatient({
    required int id,
    required String name,
    required String age,
    required String gender,
    required String phone,
    required String address,
    required String notes,
    required int expectedVersion,
  }) async {
    final token = await _getToken();

    final response = await http
        .put(
          _uri('/Patients/$id'),
          headers: _headers(token ?? ''),
          body: jsonEncode({
            'id': id,
            'patientName': name,
            'patientAge': age,
            'patientGender': gender,
            'phoneNumber': phone,
            'address': address,
            'notes': notes,
            'expectedVersion': expectedVersion,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwForResponse(response);
  }

  Future<Map<String, dynamic>> upsertPatient({
    int? serverId,
    required String name,
    required String age,
    required String gender,
    required String phone,
    required String address,
    required String notes,
    required String allergies,
    required String chronicDiseases,
    required String importantAlerts,
    int? expectedVersion,
  }) async {
    final token = await _getToken();

    final response = await http
        .post(
          _uri('/Patients/upsert'),
          headers: _headers(token ?? ''),
          body: jsonEncode({
            'id': serverId,
            'patientName': name,
            'patientAge': age,
            'patientGender': gender,
            'phoneNumber': phone,
            'address': address,
            'notes': notes,
            'allergies': allergies,
            'chronicDiseases': chronicDiseases,
            'importantAlerts': importantAlerts,
            'expectedVersion': expectedVersion,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwForResponse(response);
  }

  Future<List<dynamic>> getWaitingPatients() async {
    final token = await _getToken();

    final response = await http
        .get(_uri('/Patients/waiting'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      final patients = jsonDecode(response.body) as List<dynamic>;
      await _cacheQueuePatients(patients);
      return patients;
    }

    _throwForResponse(response);
  }

  Future<List<dynamic>> getPreviousPendingPatients() async {
    try {
      final token = await _getToken();

      final response = await http
          .get(
            _uri('/Patients/previous-pending'),
            headers: _headers(token ?? ''),
          )
          .timeout(const Duration(seconds: 15));

      if (_isSuccess(response)) {
        final patients = jsonDecode(response.body) as List<dynamic>;
        await _cacheQueuePatients(patients);
        return patients;
      }

      _throwForResponse(response);
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);
      final db = await DatabaseHelper.instance.database;
      final doctorId = await DoctorSession.getActiveDoctorIdForData();
      final today = DateTime.now().toIso8601String().split('T').first;

      if (doctorId == null) return [];

      final rows = await db.query(
        'patients',
        where: 'doctor_id = ? AND date(queue_date) < date(?) AND '
            '(queue_status = ? OR queue_status = ?)',
        whereArgs: [doctorId, today, 'Waiting', 'Serving'],
        orderBy: 'queue_date ASC, queue_no ASC, id ASC',
      );

      return rows.map((p) {
        return {
          'id': p['id'],
          'patientCode':
              p['server_id'] != null ? 'P${p['server_id']}' : 'OFF-${p['id']}',
          'queueNo': p['queue_no'] ?? p['id'],
          'queueStatus': p['queue_status'] ?? 'Waiting',
          'queueDate': p['queue_date'],
          'patientName': p['patient_name'] ?? '',
          'patientAge': p['patient_age'] ?? '',
          'patientGender': p['patient_gender'] ?? '',
          'phoneNumber': p['phone_number'] ?? '',
          'address': p['address'] ?? '',
        };
      }).toList();
    }
  }

  Future<void> movePatientToToday(int id) async {
    try {
      final token = await _getToken();

      final response = await http
          .post(
            _uri('/Patients/$id/move-to-today'),
            headers: _headers(token ?? ''),
          )
          .timeout(const Duration(seconds: 10));

      if (!_isSuccess(response)) {
        _throwForResponse(response);
      }
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);
      final db = await DatabaseHelper.instance.database;
      final today = DateTime.now().toIso8601String().split('T').first;

      final result = await db.rawQuery(
        '''
        SELECT MAX(queue_no) AS max_no
        FROM patients
        WHERE doctor_id = ? AND date(queue_date) = date(?)
        ''',
        [await DoctorSession.getActiveDoctorIdForData() ?? 0, today],
      );

      final nextQueueNo = ((result.first['max_no'] as num?)?.toInt() ?? 0) + 1;

      await db.update(
        'patients',
        {
          'queue_date': today,
          'queue_no': nextQueueNo,
          'queue_status': 'Waiting',
          'sync_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<dynamic>> getSkippedPatients() async {
    final token = await _getToken();

    final response = await http
        .get(_uri('/Patients/skipped'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      final patients = jsonDecode(response.body) as List<dynamic>;
      await _cacheQueuePatients(patients);
      return patients;
    }

    _throwForResponse(response);
  }

  Future<List<dynamic>> getCompletedPatients() async {
    final token = await _getToken();

    final response = await http
        .get(
          _uri('/Patients/completed'),
          headers: _headers(token ?? ''),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      final patients = jsonDecode(response.body) as List<dynamic>;
      await _cacheQueuePatients(patients);
      return patients;
    }

    _throwForResponse(response);
  }

  Future<void> skipPatient(int id) async {
    try {
      final token = await _getToken();

      final response = await http
          .post(_uri('/Patients/$id/skip'), headers: _headers(token ?? ''))
          .timeout(const Duration(seconds: 8));

      if (!_isSuccess(response)) {
        _throwForResponse(response);
      }
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);
      final db = await DatabaseHelper.instance.database;

      await db.update(
        'patients',
        {
          'queue_status': 'Skipped',
          'sync_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> completePatient(int id) async {
    try {
      final token = await _getToken();

      final response = await http
          .post(_uri('/Patients/$id/complete'), headers: _headers(token ?? ''))
          .timeout(const Duration(seconds: 8));

      if (!_isSuccess(response)) {
        _throwForResponse(response);
      }
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);
      final db = await DatabaseHelper.instance.database;

      await db.update(
        'patients',
        {
          'queue_status': 'Completed',
          'sync_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> setServingPatient(int id) async {
    try {
      final token = await _getToken();

      final response = await http
          .post(_uri('/Patients/$id/serving'), headers: _headers(token ?? ''))
          .timeout(const Duration(seconds: 8));

      if (!_isSuccess(response)) {
        _throwForResponse(response);
      }
    } catch (error) {
      OfflineFallbackPolicy.rethrowUnlessAllowed(error);
      final db = await DatabaseHelper.instance.database;

      await db.update(
        'patients',
        {
          'queue_status': 'Serving',
          'sync_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
