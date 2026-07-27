import 'package:http/http.dart' as http;

import 'api_config.dart';

class AutoApiResolver {
  static Future<void> resolve() async {
    if (ApiConfig.mode != 'auto') return;

    final urls = [
      ApiConfig.cloudBaseUrl,
      ApiConfig.localWifiBaseUrl,
      ApiConfig.hotspotBaseUrl,
    ];

    for (final url in urls) {
      final ok = await _ping(url);

      if (ok) {
        ApiConfig.setResolvedAutoBaseUrl(url);
        return;
      }
    }

    ApiConfig.setResolvedAutoBaseUrl('');
  }

  static Future<bool> _ping(String baseUrl) async {
    try {
      final root = baseUrl.replaceAll('/api', '');

      final response = await http
          .get(Uri.parse('$root/api/Health'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
