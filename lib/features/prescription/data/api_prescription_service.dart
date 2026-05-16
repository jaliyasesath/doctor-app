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
    });

    return Map<String, dynamic>.from(response);
  }

  // =========================
  // GET ALL PRESCRIPTIONS
  // =========================
  Future<List<Map<String, dynamic>>> getPrescriptions() async {
    final response = await _api.get('/Prescriptions');

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // GET BY PATIENT
  // =========================
  Future<List<Map<String, dynamic>>> getPrescriptionsByPatient(
    int patientId,
  ) async {
    final response = await _api.get('/Prescriptions/patient/$patientId');

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // DELETE
  // =========================
  Future<void> deletePrescription(int id) async {
    await _api.delete('/Prescriptions/$id');
  }
}