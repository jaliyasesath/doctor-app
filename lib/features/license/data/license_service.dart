import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 IMPORTANT
// device_info_plus optional import (safe handling)
import 'package:device_info_plus/device_info_plus.dart';

class LicenseService {
  static const String _installTimeKey = 'license_install_time';
  static const String _activatedKey = 'license_activated';
  static const String _licenseKeyKey = 'license_key';
  static const String _boundDeviceIdKey = 'bound_device_id';

  // 🔥 TEST MODE (10 minutes)
  // later change to: Duration(days: 7)
  static const Duration trialDuration = Duration(days: 7);

  // Demo keys
  static const List<String> validLifetimeKeys = [
    'DOCAPP-LIFE-2026',
    'CLINIC-UNLOCK-999',
    'DOCTOR-PRO-LIFETIME',
  ];

  // =========================
  // INSTALL TIME
  // =========================
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

  // =========================
  // LICENSE STATE
  // =========================
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

  // =========================
  // DEVICE ID (SAFE VERSION)
  // =========================
  static Future<String> getCurrentDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;

        // safer unique combo
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
    } catch (e) {
      // 🔥 fallback (if plugin fails)
      return 'fallback-device';
    }
  }

  // =========================
  // TRIAL LOGIC
  // =========================
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

  // =========================
  // ACTIVATION (DEVICE BOUND)
  // =========================
  /// returns:
  /// 'success'
  /// 'invalid_key'
  /// 'already_bound'
  static Future<String> activateLicense(String inputKey) async {
    final normalized = inputKey.trim();

    if (!validLifetimeKeys.contains(normalized)) {
      return 'invalid_key';
    }

    final prefs = await SharedPreferences.getInstance();
    final currentDeviceId = await getCurrentDeviceId();

    final savedBoundDeviceId = prefs.getString(_boundDeviceIdKey);

    // already bound to another device
    if (savedBoundDeviceId != null &&
        savedBoundDeviceId != currentDeviceId) {
      return 'already_bound';
    }

    // bind device
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

  // =========================
  // RESET (TESTING)
  // =========================
  static Future<void> clearLicenseForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // =========================
  // FORMAT TIME
  // =========================
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