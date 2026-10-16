import 'dart:convert';
import 'dart:typed_data';
import '../net_service/api_client.dart';

class HealthPostsService {
  final ApiClient _api = ApiClient();
  Future<Map<String, dynamic>> _map(Future<dynamic> value) async =>
      Map<String, dynamic>.from(await value as Map);
  Future<Map<String, dynamic>> summary() =>
      _map(_api.get('/health-posts/summary'));
  Future<Map<String, dynamic>> topics() =>
      _map(_api.get('/health-posts/topics'));
  Future<Map<String, dynamic>> list({
    String status = 'all',
    String search = '',
    String? cursor,
  }) {
    final query = Uri(
      queryParameters: {
        'status': status,
        'search': search,
        'pageSize': '20',
        if (cursor != null) 'before': cursor,
      },
    ).query;
    return _map(_api.get('/health-posts?$query'));
  }

  Future<Map<String, dynamic>> get(int id) =>
      _map(_api.get('/health-posts/$id'));
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body,
    String requestId,
  ) =>
      _map(_api.post('/health-posts', body, idempotencyKey: requestId));
  Future<Map<String, dynamic>> compose(int id, Map<String, dynamic> body,
          {String? photoPath}) =>
      photoPath == null
          ? _map(_api.put('/health-posts/$id/compose', body))
          : _map(_api.uploadFile('/health-posts/$id/compose',
              filePath: photoPath, fields: {'payload': jsonEncode(body)}));
  Future<void> delete(int id, int version) async {
    await _api.put('/health-posts/$id/delete', {'expectedVersion': version});
  }

  Future<Uint8List> photoBytes(int id) async =>
      (await _api.download('/health-posts/$id/photo')).bodyBytes;
}
