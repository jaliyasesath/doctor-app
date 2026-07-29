import '../../net_service/api_client.dart';

class MedicineStockApiService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> summary({
    String search = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    final query = Uri(queryParameters: {
      'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
      'lowStockThreshold': '10',
      'expiringWithinDays': '90',
    }).query;
    return Map<String, dynamic>.from(
      await _client.get('/medicine-stock/summary?$query') as Map,
    );
  }

  Future<Map<String, dynamic>> batches({
    int page = 1,
    int pageSize = 100,
    bool includeClosed = false,
  }) async {
    final query = Uri(queryParameters: {
      'page': '$page',
      'pageSize': '$pageSize',
      'includeClosed': '$includeClosed',
    }).query;
    return Map<String, dynamic>.from(
      await _client.get('/medicine-stock/batches?$query') as Map,
    );
  }

  Future<Map<String, dynamic>> movements({
    int page = 1,
    int pageSize = 100,
  }) async {
    final query = Uri(queryParameters: {
      'page': '$page',
      'pageSize': '$pageSize',
    }).query;
    return Map<String, dynamic>.from(
      await _client.get('/medicine-stock/movements?$query') as Map,
    );
  }

  Future<Map<String, dynamic>> receive(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/medicine-stock/receive', body) as Map,
      );

  Future<Map<String, dynamic>> adjust(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/medicine-stock/adjust', body) as Map,
      );

  Future<Map<String, dynamic>> dispense(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/medicine-stock/dispense', body) as Map,
      );

  Future<Map<String, dynamic>> reverseDispense(
    Map<String, dynamic> body,
  ) async =>
      Map<String, dynamic>.from(
        await _client.post('/medicine-stock/reverse-dispense', body) as Map,
      );
}
