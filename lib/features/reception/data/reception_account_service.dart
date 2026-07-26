import '../../net_service/api_client.dart';

class ReceptionAccountService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final response = await _api.get('/reception-accounts');
    if (response is! List) {
      throw const FormatException('Invalid reception account response.');
    }

    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String contactNumber,
    required String password,
  }) async {
    await _api.post('/reception-accounts', {
      'name': name,
      'email': email,
      'contactNumber': contactNumber,
      'password': password,
    });
  }

  Future<void> updateStatus({
    required int receptionId,
    required String status,
  }) async {
    await _api.put('/reception-accounts/$receptionId/status', {
      'status': status,
    });
  }

  Future<void> resetPassword({
    required int receptionId,
    required String newPassword,
  }) async {
    await _api.put('/reception-accounts/$receptionId/password', {
      'newPassword': newPassword,
    });
  }
}
