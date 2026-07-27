import 'package:http/http.dart' as http;

import '../../net_service/api_config.dart';
import '../../net_service/auto_api_resolver.dart';

class NetworkService {
  static Future<bool> isOnline() async {
    try {
      if (ApiConfig.mode == 'auto') {
        await AutoApiResolver.resolve();
      }

      final baseUrl = ApiConfig.baseUrl.trim();

      if (baseUrl.isEmpty) {
        return false;
      }

      // ApiConfig base URLs already end with /api or /API.
      // Appending /Health avoids producing /API/api/Health.
      final normalizedBaseUrl = baseUrl.replaceFirst(
        RegExp(r'/+$'),
        '',
      );
      final healthUri = Uri.parse('$normalizedBaseUrl/Health');

      final response =
          await http.get(healthUri).timeout(const Duration(seconds: 6));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
