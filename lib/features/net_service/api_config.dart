class ApiConfig {
  // =========================================
  // CONNECTION MODES
  // auto     = choose best automatically
  // cloud    = online hosted API
  // wifi     = local PC API (same WiFi)
  // hotspot  = doctor phone local server
  // offline  = local SQLite only
  // =========================================

  static String mode = 'auto';

  // =========================================
  // CLOUD API (PERMANENT FUTURE SERVER)
  // Replace later with:
  // https://api.yourclinic.com/api
  
  /// =========================================

  

         static const String cloudBaseUrl =
   // 'http://84.247.174.82:5219/api';
   'http://192.168.8.91:5219/api';

  // =========================================
  // LOCAL WIFI API (PC/LAPTOP API)
  // Same WiFi router required
  // =========================================

  static const String localWifiBaseUrl =
      'http://192.168.8.91:5219/api';
       //'http://172.20.10.4:5219/api';

      


  // =========================================
  // DOCTOR PHONE HOTSPOT LOCAL SERVER
  // Automatically updated after QR scan
  // =========================================

  static const String hotspotBaseUrl =
      'http://192.168.43.1:8080/api';

  static String customHotspotBaseUrl =
      hotspotBaseUrl;

  // =========================================
  // AUTO MODE RESOLUTION
  // =========================================

  static String _resolvedAutoBaseUrl =
      cloudBaseUrl;

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

  static void setResolvedAutoBaseUrl(
    String url,
  ) {
    _resolvedAutoBaseUrl = url;
  }

  // =========================================
  // HOTSPOT QR URL UPDATE
  // =========================================

  static void setHotspotBaseUrl(
    String url,
  ) {
    customHotspotBaseUrl = url;
  }

  // =========================================
  // HELPERS
  // =========================================

  static bool get isOffline =>
      mode == 'offline';

  static bool get isCloud =>
      mode == 'cloud';

  static bool get isWifi =>
      mode == 'wifi';

  static bool get isHotspot =>
      mode == 'hotspot';

  static bool get isAuto =>
      mode == 'auto';
}