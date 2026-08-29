import '../../net_service/api_client.dart';

class LabApiService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> getLabs() async {
    final response = await _api.get('/Laboratories');
    return (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> saveLab(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
        await _api.post('/Laboratories/upsert', data) as Map,
      );

  Future<void> deleteLab(int id, int version) async =>
      _api.delete('/Laboratories/$id?expectedVersion=$version');

  Future<void> sendTestEmail(int id) async =>
      _api.post('/Laboratories/$id/test-email', {});

  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> data, {
    String? idempotencyKey,
  }) async =>
      Map<String, dynamic>.from(await _api.post(
        '/lab-orders',
        data,
        idempotencyKey: idempotencyKey,
      ) as Map);

  Future<Map<String, dynamic>> sendOrder(int id, String key) async =>
      Map<String, dynamic>.from(
        await _api.post('/lab-orders/$id/send-email', {'idempotencyKey': key})
            as Map,
      );
}
