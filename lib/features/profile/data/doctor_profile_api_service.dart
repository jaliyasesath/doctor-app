import '../../net_service/api_client.dart';

class DoctorProfileApiService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getProfile() async =>
      Map<String, dynamic>.from(await _api.get('/doctor-profile') as Map);

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(await _api.put('/doctor-profile', data) as Map);

  Future<Map<String, dynamic>> uploadMedia(String kind, String filePath) async =>
      Map<String, dynamic>.from(await _api.uploadFile(
        '/doctor-profile/media/$kind',
        filePath: filePath,
      ) as Map);

  Future<Map<String, dynamic>> removeMedia(String kind) async =>
      Map<String, dynamic>.from(
        await _api.delete('/doctor-profile/media/$kind') as Map,
      );
}
