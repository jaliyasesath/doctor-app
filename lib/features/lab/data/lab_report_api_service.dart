import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../net_service/api_client.dart';

class LabReportApiService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> getReports({
    int? patientId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final parameters = <String, String>{
      if (patientId != null) 'patientId': patientId.toString(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    final uri = Uri(path: '/lab-reports', queryParameters: parameters);
    final response = await _api.get(uri.toString());
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
