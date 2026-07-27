import '../../net_service/api_client.dart';

class ApiSubscriptionService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getMySubscription() async {
    final response = await _api.get('/Subscriptions/my');

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> activateSubscription({
    required int doctorId,
    required String planName,
    String? deviceId,
  }) async {
    final response = await _api.post('/Subscriptions/activate', {
      'doctorId': doctorId,
      'planName': planName,
      'deviceId': deviceId,
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
}
