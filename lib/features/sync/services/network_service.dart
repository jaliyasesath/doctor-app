import 'package:http/http.dart' as http;

import '../../net_service/api_config.dart';
import '../../net_service/auto_api_resolver.dart';

class NetworkService {
  static Future<bool> isOnline() async {
    try {
      if (ApiConfig.mode == 'auto') {
        await AutoApiResolver.resolve();
      }

      final baseUrl = ApiConfig.baseUrl;

      if (baseUrl.trim().isEmpty) {
        return false;
      }

      final base = baseUrl.replaceAll('/api', '');

      final response = await http
          .get(Uri.parse('$base/api/Health'))
          .timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}