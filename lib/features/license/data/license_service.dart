import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'api_subscription_service.dart';

class LicenseService {
  static const String _installTimeKey = 'license_install_time';
  static const String _activatedKey = 'license_activated';
  static const String _licenseKeyKey = 'license_key';
  static const String _boundDeviceIdKey = 'bound_device_id';
  static const String _cachedPlanKey = 'cached_plan_name';
  static const String _cachedEndDateKey = 'cached_end_date';
  static const String _cachedDaysKey = 'cached_days_remaining';
  static const String _lastOnlineCheckKey = 'last_online_check';

  static const Duration trialDuration = Duration(days: 30);
  //static const Duration trialDuration = Duration(minutes: 1);
  //static const Duration trialDuration = Duration(seconds: 30);

  static const List<String> validLifetimeKeys = [
    'DOCAPP-LIFE-2026',
    'CLINIC-UNLOCK-999',
    'DOCTOR-PRO-LIFETIME',
  ];

  static Future<void> ensureInstallTime() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installTimeKey);

    if (existing == null) {
      await prefs.setString(
        _installTimeKey,
        DateTime.now().toIso8601String(),
      );
    }
  }

  static Future<DateTime?> getInstallTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_installTimeKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activatedKey) ?? false;
  }

  static Future<String?> getSavedLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKeyKey);
  }

  static Future<String?> getBoundDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_boundDeviceIdKey);
  }

  static Future<String> getCurrentDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return 'android-${android.id}-${android.model}-${android.brand}';
      }

      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return 'ios-${ios.identifierForVendor ?? 'unknown'}';
      }

      if (Platform.isWindows) {
        final windows = await deviceInfo.windowsInfo;
        return 'windows-${windows.deviceId}';
      }

      if (Platform.isLinux) {
        final linux = await deviceInfo.linuxInfo;
        return 'linux-${linux.machineId ?? 'unknown'}';
      }

      if (Platform.isMacOS) {
        final mac = await deviceInfo.macOsInfo;
        return 'mac-${mac.systemGUID ?? 'unknown'}';
      }

      return 'unknown-device';
    } catch (_) {
      return 'fallback-device';
    }
  }

  static Future<Duration?> getRemainingTrialTime() async {
    await ensureInstallTime();

    final activated = await isActivated();
    if (activated) return null;

    final installTime = await getInstallTime();
    if (installTime == null) return Duration.zero;

    final expiry = installTime.add(trialDuration);
    final remaining = expiry.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  static Future<bool> isTrialExpired() async {
    final activated = await isActivated();
    if (activated) return false;

    final remaining = await getRemainingTrialTime();
    return remaining == null ? false : remaining <= Duration.zero;
  }

  static Future<bool> hasActiveSubscription() async {
    try {
      final api = ApiSubscriptionService();
      final result = await api.getMySubscription();

      return result['canUseApp'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveSubscriptionCache({
    required String planName,
    required DateTime endDate,
    required int daysRemaining,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_cachedPlanKey, planName);

    await prefs.setString(
      _cachedEndDateKey,
      endDate.toIso8601String(),
    );

    await prefs.setInt(_cachedDaysKey, daysRemaining);

    await prefs.setString(
      _lastOnlineCheckKey,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<Map<String, dynamic>> getCachedSubscription() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'planName': prefs.getString(_cachedPlanKey) ?? '',
      'endDate': prefs.getString(_cachedEndDateKey),
      'daysRemaining': prefs.getInt(_cachedDaysKey) ?? 0,
      'lastOnlineCheck': prefs.getString(_lastOnlineCheckKey),
    };
  }

  static Future<bool> isCachedSubscriptionValid() async {
    final prefs = await SharedPreferences.getInstance();

    final rawEndDate = prefs.getString(_cachedEndDateKey);

    if (rawEndDate == null) {
      return false;
    }

    final endDate = DateTime.tryParse(rawEndDate);

    if (endDate == null) {
      return false;
    }

    return DateTime.now().isBefore(endDate);
  }

  static Future<String> activateLicense(String inputKey) async {
    final normalized = inputKey.trim();

    if (!validLifetimeKeys.contains(normalized)) {
      return 'invalid_key';
    }

    final prefs = await SharedPreferences.getInstance();
    final currentDeviceId = await getCurrentDeviceId();

    final savedBoundDeviceId = prefs.getString(_boundDeviceIdKey);

    if (savedBoundDeviceId != null && savedBoundDeviceId != currentDeviceId) {
      return 'already_bound';
    }

    await prefs.setBool(_activatedKey, true);
    await prefs.setString(_licenseKeyKey, normalized);
    await prefs.setString(_boundDeviceIdKey, currentDeviceId);

    return 'success';
  }

  static Future<bool> isCurrentDeviceAuthorized() async {
    final activated = await isActivated();
    if (!activated) return true;

    final bound = await getBoundDeviceId();
    if (bound == null) return false;

    final current = await getCurrentDeviceId();
    return bound == current;
  }

  static Future<void> clearLicenseForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static String formatDuration(Duration duration) {
    if (duration <= Duration.zero) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }

    return '${duration.inMinutes}m ${seconds}s';
  }
}
