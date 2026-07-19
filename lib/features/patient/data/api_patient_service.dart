import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../net_service/api_config.dart';
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

    throw Exception('API failed');

  } catch (_) {

    // ====================================
    // LOCAL SQLITE FALLBACK
    // ====================================

    final db = await DatabaseHelper.instance.database;

    final waiting = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
        SELECT COUNT(*) FROM patients
        WHERE queue_status = 'Waiting'
        ''',
      ),
    ) ?? 0;

    final serving = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
        SELECT COUNT(*) FROM patients
        WHERE queue_status = 'Serving'
        ''',
      ),
    ) ?? 0;

    final completed = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
        SELECT COUNT(*) FROM patients
        WHERE queue_status = 'Completed'
        ''',
      ),
    ) ?? 0;

    final skipped = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
        SELECT COUNT(*) FROM patients
        WHERE queue_status = 'Skipped'
        ''',
      ),
    ) ?? 0;

    return {
      'waiting': waiting,
      'serving': serving,
      'completed': completed,
      'skipped': skipped,
    };
  }
}

  
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
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
      throw Exception('API base URL is empty. App is in offline mode.');
    }

    return Uri.parse('$baseUrl$path');
  }

  bool _isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<List<dynamic>> getPatients({
  int page = 1,
  int pageSize = 100,
  String? updatedAfter,
}) async {
  final token = await _getToken();

  final query =
      '/Patients?page=$page&pageSize=$pageSize'
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

  throw Exception('Failed to load patients (${response.statusCode})');
}

  Future<Map<String, dynamic>> getPatientById(int id) async {
    final token = await _getToken();

    final response = await http
        .get(_uri('/Patients/$id'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load patient (${response.statusCode})');
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

  throw Exception('Failed to search patients (${response.statusCode})');
}

  Future<void> deletePatient(int id) async {
    final token = await _getToken();

    final response = await http
        .delete(_uri('/Patients/$id'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response)) {
      throw Exception('Delete failed (${response.statusCode})');
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

      throw Exception('Add patient failed (${response.statusCode})');
    } catch (_) {
      final doctorId = await DoctorSession.getDoctorId() ?? 0;

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
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to update patient (${response.statusCode})');
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
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Upsert patient failed (${response.statusCode})');
  }

  Future<List<dynamic>> getWaitingPatients() async {
    final token = await _getToken();

    final response = await http
        .get(_uri('/Patients/waiting'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 15));

    if (_isSuccess(response)) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception('Failed to load waiting patients (${response.statusCode})');
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
        return jsonDecode(response.body) as List<dynamic>;
      }

      throw Exception(
        'Failed to load previous pending patients '
        '(${response.statusCode})',
      );
    } catch (_) {
      final db = await DatabaseHelper.instance.database;
      final today = DateTime.now().toIso8601String().split('T').first;

      final rows = await db.query(
        'patients',
        where:
            'date(queue_date) < date(?) AND '
            '(queue_status = ? OR queue_status = ?)',
        whereArgs: [today, 'Waiting', 'Serving'],
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
        throw Exception('API move-to-today failed');
      }
    } catch (_) {
      final db = await DatabaseHelper.instance.database;
      final today = DateTime.now().toIso8601String().split('T').first;

      final result = await db.rawQuery(
        '''
        SELECT MAX(queue_no) AS max_no
        FROM patients
        WHERE date(queue_date) = date(?)
        ''',
        [today],
      );

      final nextQueueNo =
          ((result.first['max_no'] as num?)?.toInt() ?? 0) + 1;

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
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception('Failed to load skipped patients (${response.statusCode})');
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
    return jsonDecode(response.body) as List<dynamic>;
  }

  throw Exception(
    'Failed to load completed patients (${response.statusCode})',
  );
}

  Future<void> skipPatient(int id) async {
  try {
    final token = await _getToken();

    final response = await http
        .post(_uri('/Patients/$id/skip'), headers: _headers(token ?? ''))
        .timeout(const Duration(seconds: 8));

    if (!_isSuccess(response)) {
      throw Exception('API skip failed');
    }
  } catch (_) {
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
      throw Exception('API complete failed');
    }
  } catch (_) {
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
      throw Exception('API serving failed');
    }
  } catch (_) {
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
