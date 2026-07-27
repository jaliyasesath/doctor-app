import '../../net_service/api_client.dart';

class ApiAdminSubscriptionService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> getDoctorsWithSubscription() async {
    final response = await _api.get('/Subscriptions/admin/doctors');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> activateSubscription({
    required int doctorId,
    required String planName,
  }) async {
    final response = await _api.post('/Subscriptions/activate', {
      'doctorId': doctorId,
      'planName': planName,
      'deviceId': null,
    });

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> extendSubscription({
    required int doctorId,
    required int months,
  }) async {
    final response = await _api.post('/Subscriptions/extend', {
      'doctorId': doctorId,
      'months': months,
    });

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> deactivateSubscription({
    required int doctorId,
  }) async {
    final response = await _api.post('/Subscriptions/deactivate', {
      'doctorId': doctorId,
    });

    return Map<String, dynamic>.from(response);
  }
}
