import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../net_service/api_client.dart';

class LabReportApiService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> getReports({int? patientId}) async {
    final response = await _api.get(patientId == null ? '/lab-reports' : '/lab-reports?patientId=$patientId');
    return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> downloadReport(Map<String, dynamic> report) async {
    final response = await _api.download('/lab-reports/${report['id']}/download');
    final directory = await getTemporaryDirectory();
    final safeName = (report['originalFileName']?.toString() ?? 'lab-report.pdf')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  Future<Map<String, dynamic>> review({required int id, required String status, required String notes, required int version}) async =>
      Map<String, dynamic>.from(await _api.put('/lab-reports/$id/review', {
        'status': status, 'notes': notes, 'expectedVersion': version,
      }) as Map);
}
