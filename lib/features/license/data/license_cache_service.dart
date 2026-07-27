import 'package:shared_preferences/shared_preferences.dart';

class LicenseCacheService {
  static const String _isActiveKey = 'license_is_active';
  static const String _isExpiredKey = 'license_is_expired';
  static const String _planNameKey = 'license_plan_name';
  static const String _endDateKey = 'license_end_date';
  static const String _daysRemainingKey = 'license_days_remaining';
  static const String _lastCheckedKey = 'license_last_checked';

  static Future<void> saveLicense(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_isActiveKey, data['isActive'] == true);
    await prefs.setBool(_isExpiredKey, data['isExpired'] == true);
    await prefs.setString(_planNameKey, data['planName']?.toString() ?? '');
    await prefs.setString(_endDateKey, data['endDate']?.toString() ?? '');
    await prefs.setInt(
      _daysRemainingKey,
      int.tryParse(data['daysRemaining']?.toString() ?? '0') ?? 0,
    );
    await prefs.setString(_lastCheckedKey, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>> getCachedLicense() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'isActive': prefs.getBool(_isActiveKey) ?? false,
      'isExpired': prefs.getBool(_isExpiredKey) ?? true,
      'planName': prefs.getString(_planNameKey) ?? '',
      'endDate': prefs.getString(_endDateKey) ?? '',
      'daysRemaining': prefs.getInt(_daysRemainingKey) ?? 0,
      'lastChecked': prefs.getString(_lastCheckedKey) ?? '',
    };
  }

  static Future<bool> isLicenseValidOffline() async {
    final data = await getCachedLicense();

    final isActive = data['isActive'] == true;
    final isExpired = data['isExpired'] == true;
    final endDateText = data['endDate']?.toString() ?? '';

    if (!isActive || isExpired || endDateText.isEmpty) return false;

    final endDate = DateTime.tryParse(endDateText);
    if (endDate == null) return false;

    return endDate.isAfter(DateTime.now());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_isActiveKey);
    await prefs.remove(_isExpiredKey);
    await prefs.remove(_planNameKey);
    await prefs.remove(_endDateKey);
    await prefs.remove(_daysRemainingKey);
    await prefs.remove(_lastCheckedKey);
  }
}
