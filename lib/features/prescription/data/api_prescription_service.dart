import '../../net_service/api_client.dart';

class ApiPrescriptionService {
  final ApiClient _api = ApiClient();

  // =========================
  // UPSERT (CREATE / UPDATE)
  // =========================
  Future<Map<String, dynamic>> upsertPrescription({
    int? serverId,
    required int serverPatientId,
    required String prescriptionNo,
    required String prescriptionDate,
    required String complaint,
    required String diagnosis,
    required String visitNotes,
    required String qrValue,
    required List<Map<String, dynamic>> items,
    int? expectedVersion,
    String? idempotencyKey,
  }) async {
    final response = await _api.post('/Prescriptions/upsert', {
      'id': serverId,
      'patientId': serverPatientId,
      'prescriptionNo': prescriptionNo,
      'prescriptionDate': prescriptionDate,
      'complaint': complaint,
      'diagnosis': diagnosis,
      'visitNotes': visitNotes,
      'qrValue': qrValue,
      'items': items,
      'expectedVersion': expectedVersion,
    }, idempotencyKey: idempotencyKey);

    return Map<String, dynamic>.from(response);
  }

  // =========================
  // GET ALL PRESCRIPTIONS
  // =========================
  Future<List<Map<String, dynamic>>> getPrescriptions({
    int page = 1,
    int pageSize = 100,
    String? updatedAfter,
  }) async {
    final query = '/Prescriptions?page=$page&pageSize=$pageSize'
        '${updatedAfter != null ? '&updatedAfter=${Uri.encodeQueryComponent(updatedAfter)}' : ''}';

    final response = await _api.get(query);

    if (response is Map && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    }

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // GET BY PATIENT
  // =========================
  Future<List<Map<String, dynamic>>> getPrescriptionsByPatient(
    int patientId, {
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _api.get(
      '/Prescriptions/patient/$patientId?page=$page&pageSize=$pageSize',
    );

    if (response is Map && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    }

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // DELETE
  // =========================
  Future<void> deletePrescription(int id, int expectedVersion) async {
    await _api.delete(
      '/Prescriptions/$id?expectedVersion=$expectedVersion',
    );
  }
}
