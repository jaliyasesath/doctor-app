import '../../net_service/api_client.dart';

class MedicineStockApiService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> summary({
    String search = '',
    int page = 1,
    int pageSize = 100,
    int lowStockThreshold = 10,
    int expiringWithinDays = 90,
  }) async {
    final query = Uri(queryParameters: {
      'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
      'lowStockThreshold': '$lowStockThreshold',
      'expiringWithinDays': '$expiringWithinDays',
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

  Future<Map<String, dynamic>> pendingPrescriptions({
    String search = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    final query = Uri(queryParameters: {
      'search': search,
      'page': '$page',
      'pageSize': '$pageSize',
    }).query;
    return Map<String, dynamic>.from(
      await _client.get('/medicine-stock/pending-prescriptions?$query') as Map,
    );
  }

  Future<Map<String, dynamic>> valuation() async =>
      Map<String, dynamic>.from(
        await _client.get('/medicine-stock/valuation') as Map,
      );

  Future<Map<String, dynamic>> allSummary({
    String search = '',
    int lowStockThreshold = 10,
    int expiringWithinDays = 90,
  }) => _allPages((page) => summary(
        search: search,
        page: page,
        lowStockThreshold: lowStockThreshold,
        expiringWithinDays: expiringWithinDays,
      ));

  Future<Map<String, dynamic>> allBatches() =>
      _allPages((page) => batches(page: page));

  Future<Map<String, dynamic>> allMovements() =>
      _allPages((page) => movements(page: page));

  Future<Map<String, dynamic>> _allPages(
    Future<Map<String, dynamic>> Function(int page) loader,
  ) async {
    final data = <dynamic>[];
    var page = 1;
    while (true) {
      final response = await loader(page);
      final rows = response['data'];
      if (rows is List) data.addAll(rows);
      if (response['hasMore'] != true) break;
      page++;
    }
    return {'data': data, 'total': data.length, 'hasMore': false};
  }
}
