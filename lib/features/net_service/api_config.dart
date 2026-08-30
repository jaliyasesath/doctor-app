import 'package:flutter/foundation.dart';

class ApiConfig {
  // Current connection mode
  static String mode = 'cloud';

  // Temporary VPS HTTP configuration for UAT testing.
  // Replace with HTTPS and set allowInsecureCloudHttp to false
  // before the public production release.
  static const String cloudBaseUrl = String.fromEnvironment(
    'PP_CLOUD_API_URL',
    defaultValue: 'http://169.58.40.160/api',
  );

  static const bool allowInsecureCloudHttp = bool.fromEnvironment(
    'PP_ALLOW_INSECURE_HTTP',
    defaultValue: true,
  );

  // Local computer API
  static const String localWifiBaseUrl =
      'http://192.168.8.91:5219/api';

  // Doctor phone hotspot API
  static const String hotspotBaseUrl =
      'http://192.168.43.1:8080/api';

  static String customHotspotBaseUrl = hotspotBaseUrl;
  static String hotspotPairingToken = '';
  static DateTime? hotspotPairingExpiresAt;
  static String _resolvedAutoBaseUrl = cloudBaseUrl;

  static String get baseUrl {
    switch (mode) {
      case 'cloud':
        return _secureCloudUrl;

      case 'wifi':
        return _normalize(localWifiBaseUrl);

      case 'hotspot':
        return _normalize(customHotspotBaseUrl);

      case 'offline':
        return '';

      case 'auto':
        return _normalize(_resolvedAutoBaseUrl);

      default:
        return _secureCloudUrl;
    }
  }

  static String get _secureCloudUrl {
    final value = _normalize(cloudBaseUrl);

    if (value.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(value);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '';
    }

    final isHttps = uri.scheme.toLowerCase() == 'https';
    final isHttp = uri.scheme.toLowerCase() == 'http';

    if (!isHttps && !isHttp) {
      return '';
    }

    if (kReleaseMode && !allowInsecureCloudHttp && !isHttps) {
      return '';
    }

    return value;
  }

  static String _normalize(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static void setMode(String newMode) {
    switch (newMode) {
      case 'cloud':
      case 'wifi':
      case 'hotspot':
      case 'offline':
      case 'auto':
        mode = newMode;
        break;

      default:
        mode = 'cloud';
    }
  }

  static void setResolvedAutoBaseUrl(String url) {
    _resolvedAutoBaseUrl = _normalize(url);
  }

  static void setHotspotBaseUrl(String url) {
    customHotspotBaseUrl = _normalize(url);
  }

  static void setHotspotPairingToken(
    String token, {
    DateTime? expiresAt,
  }) {
    hotspotPairingToken = token.trim();
    hotspotPairingExpiresAt = expiresAt;
  }

  static bool get hasValidHotspotPairing {
    return hotspotPairingToken.isNotEmpty &&
        hotspotPairingExpiresAt != null &&
        hotspotPairingExpiresAt!.isAfter(DateTime.now().toUtc());
  }

  static void clearHotspotPairing() {
    hotspotPairingToken = '';
    hotspotPairingExpiresAt = null;
    customHotspotBaseUrl = hotspotBaseUrl;
  }

  static bool get isOffline => mode == 'offline';
  static bool get isCloud => mode == 'cloud';
  static bool get isWifi => mode == 'wifi';
  static bool get isHotspot => mode == 'hotspot';
  static bool get isAuto => mode == 'auto';
}