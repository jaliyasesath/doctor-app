// import 'package:flutter/foundation.dart';

// class ApiConfig {
//   // VPS API 
//   static String mode = 'cloud';

//   // Supply on production builds with:
//   // --dart-define=PP_CLOUD_API_URL=https://your-domain.example/api
//   static const String cloudBaseUrl = String.fromEnvironment(
//     'PP_CLOUD_API_URL',
//     defaultValue: 'http://169.58.40.160/api',
//   );

//   // Local computer API
//   static const String localWifiBaseUrl = 'http://192.168.8.91:5219/api';

//   // Doctor phone hotspot server
//   static const String hotspotBaseUrl = 'http://192.168.43.1:8080/api';

//   static String customHotspotBaseUrl = hotspotBaseUrl;

//   static String _resolvedAutoBaseUrl = cloudBaseUrl;

//   static String get baseUrl {
//     switch (mode) {
//       case 'cloud':
//         return _secureCloudUrl;

//       case 'wifi':
//         return localWifiBaseUrl;

//       case 'hotspot':
//         return customHotspotBaseUrl;

//       case 'offline':
//         return '';

//       case 'auto':
//       default:
//         return _resolvedAutoBaseUrl;
//     }
//   }

//   static String get _secureCloudUrl {
//     final value = cloudBaseUrl.trim();
//     if (kReleaseMode && !value.toLowerCase().startsWith('https://')) {
//       return '';
//     }
//     return value;
//   }

//   static void setMode(String newMode) {
//     mode = newMode;
//   }

//   static void setResolvedAutoBaseUrl(String url) {
//     _resolvedAutoBaseUrl = url;
//   }

//   static void setHotspotBaseUrl(String url) {
//     customHotspotBaseUrl = url;
//   }

//   static bool get isOffline => mode == 'offline';
//   static bool get isCloud => mode == 'cloud';
//   static bool get isWifi => mode == 'wifi';
//   static bool get isHotspot => mode == 'hotspot';
//   static bool get isAuto => mode == 'auto';
// }


import 'package:flutter/foundation.dart';

class ApiConfig {
  // VPS API 
  static String mode = 'cloud';

  // Supply on production builds with:
  // --dart-define=PP_CLOUD_API_URL=https://your-domain.example/api
  static const String cloudBaseUrl = String.fromEnvironment(
    'PP_CLOUD_API_URL',
    defaultValue: 'http://169.58.40.160/api',
  );

  // Temporary cross-platform testing switch for a VPS that has no TLS yet.
  // Never enable this flag for a public production build.
 static const bool allowInsecureCloudHttp = bool.fromEnvironment(
  'PP_ALLOW_INSECURE_HTTP',
  defaultValue: true,
);

  // Local computer API
  static const String localWifiBaseUrl = 'http://192.168.8.91:5219/api';

  // Doctor phone hotspot server
  static const String hotspotBaseUrl = 'http://192.168.43.1:8080/api';

  static String customHotspotBaseUrl = hotspotBaseUrl;

  static String _resolvedAutoBaseUrl = cloudBaseUrl;

  static String get baseUrl {
    switch (mode) {
      case 'cloud':
        return _secureCloudUrl;

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

  static String get _secureCloudUrl {
    final value = cloudBaseUrl.trim();
    if (kReleaseMode &&
        !allowInsecureCloudHttp &&
        !value.toLowerCase().startsWith('https://')) {
      return '';
    }
    return value;
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

