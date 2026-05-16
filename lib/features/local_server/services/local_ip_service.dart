import 'package:network_info_plus/network_info_plus.dart';

class LocalIpService {
  static Future<String> getLocalApiUrl() async {
    final info = NetworkInfo();

    final ip = await info.getWifiIP();

    if (ip == null || ip.isEmpty) {
      throw Exception(
        'Unable to detect WiFi IP',
      );
    }

    return 'http://$ip:8080/api';
  }
}