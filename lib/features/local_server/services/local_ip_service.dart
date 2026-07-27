import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

class LocalIpService {
  static Future<String> getLocalApiUrl() async {
    final info = NetworkInfo();

    final wifiIp = await info.getWifiIP();
    if (_isPrivateIpv4(wifiIp)) {
      return 'http://$wifiIp:8080/api';
    }

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    final privateAddresses = interfaces
        .expand((item) => item.addresses)
        .map((item) => item.address)
        .where(_isPrivateIpv4)
        .toList();

    if (privateAddresses.isNotEmpty) {
      final preferred = privateAddresses.firstWhere(
        _isLikelyHotspotGateway,
        orElse: () => privateAddresses.first,
      );
      return 'http://$preferred:8080/api';
    }

    // Common gateway addresses used by the phone hosting the hotspot.
    // The screen allows the doctor to retry after enabling the hotspot.
    final fallback = Platform.isIOS ? '172.20.10.1' : '192.168.43.1';
    return 'http://$fallback:8080/api';
  }

  static bool _isPrivateIpv4(String? value) {
    if (value == null || value.isEmpty) return false;
    if (value.startsWith('10.')) return true;
    if (value.startsWith('192.168.')) return true;

    final parts = value.split('.');
    if (parts.length != 4 || parts.first != '172') return false;

    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  static bool _isLikelyHotspotGateway(String value) {
    return value.endsWith('.1') ||
        value.startsWith('192.168.43.') ||
        value.startsWith('192.168.194.') ||
        value.startsWith('172.20.10.');
  }
}
