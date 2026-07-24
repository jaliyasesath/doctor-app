class ApiConfig {
  // =========================================
  // CONNECTION MODES
  // =========================================

  // Local API එක force කිරීමට wifi දාන්න.
  static String mode = 'wifi';

  // =========================================
  // CLOUD API - VPS
  // Local testing වෙලාවේ භාවිතා නොවේ.
  // =========================================

  static const String cloudBaseUrl =
      'http://169.58.40.160:5219/API';

  // =========================================
  // LOCAL WIFI API
  // Computer IPv4 address = 192.168.8.91
  // =========================================

  static const String localWifiBaseUrl =
      'http://192.168.8.91:5219/api';

  // =========================================
  // DOCTOR PHONE HOTSPOT SERVER
  // =========================================

  static const String hotspotBaseUrl =
      'http://192.168.43.1:8080/api';

  static String customHotspotBaseUrl = hotspotBaseUrl;

  // =========================================
  // AUTO MODE URL
  // =========================================

  static String _resolvedAutoBaseUrl = cloudBaseUrl;

  // =========================================
  // CURRENT ACTIVE BASE URL
  // =========================================

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

  // =========================================
  // SET CONNECTION MODE
  // =========================================

  static void setMode(String newMode) {
    mode = newMode;
  }

  // =========================================
  // AUTO MODE URL UPDATE
  // =========================================

  static void setResolvedAutoBaseUrl(String url) {
    _resolvedAutoBaseUrl = url;
  }

  // =========================================
  // HOTSPOT URL UPDATE
  // =========================================

  static void setHotspotBaseUrl(String url) {
    customHotspotBaseUrl = url;
  }

  // =========================================
  // HELPERS
  // =========================================

  static bool get isOffline => mode == 'offline';
  static bool get isCloud => mode == 'cloud';
  static bool get isWifi => mode == 'wifi';
  static bool get isHotspot => mode == 'hotspot';
  static bool get isAuto => mode == 'auto';
}