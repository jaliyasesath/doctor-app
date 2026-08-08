import '../../net_service/api_client.dart';

class DoctorProfileApiService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getProfile() async =>
      Map<String, dynamic>.from(await _api.get('/doctor-profile') as Map);

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(await _api.put('/doctor-profile', data) as Map);
}
