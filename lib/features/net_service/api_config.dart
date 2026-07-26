class ApiConfig {
  // VPS API භාවිතා කිරීම
  static String mode = 'cloud';

  // Temporary HTTP VPS address
  static const String cloudBaseUrl =
      'http://169.58.40.160/api';

  // Local computer API
  static const String localWifiBaseUrl =
      'http://192.168.8.91:5219/api';

  // Doctor phone hotspot server
  static const String hotspotBaseUrl =
      'http://192.168.43.1:8080/api';

  static String customHotspotBaseUrl = hotspotBaseUrl;

  static String _resolvedAutoBaseUrl = cloudBaseUrl;

  static String get baseUrl {
    switch (mode) {
      case 'cloud':
        return cloudBaseUrl;

      case 'wifi':
        return localWifiBaseUrl;

      case 'hotspot':
        return customHotspotBaseUrl;

      case 'offline':
        return '';

      case 'auto':
      default:
        return _resolvedAutoBaseUrl;
    }
  }

  static void setMode(String newMode) {
    mode = newMode;
  }

  static void setResolvedAutoBaseUrl(String url) {
    _resolvedAutoBaseUrl = url;
  }

  static void setHotspotBaseUrl(String url) {
    customHotspotBaseUrl = url;
  }

  static bool get isOffline => mode == 'offline';
  static bool get isCloud => mode == 'cloud';
  static bool get isWifi => mode == 'wifi';
  static bool get isHotspot => mode == 'hotspot';
  static bool get isAuto => mode == 'auto';
}