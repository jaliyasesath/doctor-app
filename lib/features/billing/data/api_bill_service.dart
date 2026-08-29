import '../../net_service/api_client.dart';

class ApiBillService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> upsertBill({
    int? serverId,
    int? serverPatientId,
    int? serverPrescriptionId,
    required String prescriptionNo,
    required double consultationFee,
    required double medicineCharges,
    required double otherCharges,
    required double discountAmount,
    required double totalAmount,
    required double paidAmount,
    required double balanceAmount,
    required String paymentMethod,
    required String paymentStatus,
    required String notes,
    int? expectedVersion,
    String? idempotencyKey,
  }) async {
    final response = await _api.post('/Bills/upsert', {
      'id': serverId,
      'patientId': serverPatientId,
      'prescriptionId': serverPrescriptionId,
      'prescriptionNo': prescriptionNo,
      'consultationFee': consultationFee,
      'medicineCharges': medicineCharges,
      'otherCharges': otherCharges,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'expectedVersion': expectedVersion,
    }, idempotencyKey: idempotencyKey);

    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBills({
    int page = 1,
    int pageSize = 100,
    String? updatedAfter,
  }) async {
    final query = '/Bills?page=$page&pageSize=$pageSize'
        '${updatedAfter == null ? '' : '&updatedAfter=${Uri.encodeQueryComponent(updatedAfter)}'}';
    final response = await _api.get(query);

    if (response is Map && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    }
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteBill(int serverId, int expectedVersion) async {
    await _api.delete(
      '/Bills/$serverId?expectedVersion=$expectedVersion',
    );
  }
}
