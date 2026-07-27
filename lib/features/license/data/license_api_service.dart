import '../../net_service/api_client.dart';
import '../../sync/services/network_service.dart';
import 'license_cache_service.dart';

class LicenseApiService {
  final ApiClient _api = ApiClient();

  // =========================
  // GET LICENSE STATUS
  // Online  -> API status + cache save
  // Offline -> cached license return
  // =========================
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final online = await NetworkService.isOnline();

      if (!online) {
        final cached = await LicenseCacheService.getCachedLicense();
        final validOffline = await LicenseCacheService.isLicenseValidOffline();

        return {
          'success': validOffline,
          'mode': 'offline',
          'data': cached,
          'message': validOffline
              ? 'Offline license valid'
              : 'No valid offline license',
        };
      }

      final response = await _api.get('/License/status');

      final data = Map<String, dynamic>.from(response);

      await LicenseCacheService.saveLicense(data);

      return {
        'success': true,
        'mode': 'online',
        'data': data,
      };
    } catch (e) {
      final cached = await LicenseCacheService.getCachedLicense();
      final validOffline = await LicenseCacheService.isLicenseValidOffline();

      return {
        'success': validOffline,
        'mode': 'offline_fallback',
        'data': cached,
        'message':
            validOffline ? 'Using cached license' : 'License check failed: $e',
      };
    }
  }

  // =========================
  // VALIDATE DEVICE LICENSE
  // =========================
  Future<Map<String, dynamic>> validate({
    required String deviceId,
  }) async {
    try {
      final online = await NetworkService.isOnline();

      if (!online) {
        final cached = await LicenseCacheService.getCachedLicense();
        final validOffline = await LicenseCacheService.isLicenseValidOffline();

        return {
          'success': validOffline,
          'mode': 'offline',
          'data': cached,
          'message': validOffline
              ? 'Offline validation success'
              : 'No valid offline license',
        };
      }

      final response = await _api.post(
        '/License/validate',
        {
          'deviceId': deviceId,
        },
      );

      final data = Map<String, dynamic>.from(response);

      if (data['valid'] == true) {
        await LicenseCacheService.saveLicense({
          'isActive': true,
          'isExpired': false,
          'planName': data['planName'] ?? '',
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'daysRemaining': data['daysRemaining'] ?? 0,
        });
      }

      return {
        'success': data['valid'] == true,
        'mode': 'online',
        'data': data,
        'message': data['message']?.toString() ?? '',
      };
    } catch (e) {
      final cached = await LicenseCacheService.getCachedLicense();
      final validOffline = await LicenseCacheService.isLicenseValidOffline();

      return {
        'success': validOffline,
        'mode': 'offline_fallback',
        'data': cached,
        'message': validOffline
            ? 'Using cached license'
            : 'License validation failed: $e',
      };
    }
  }

  // =========================
  // ACTIVATE / RENEW LICENSE
  // Online only
  // =========================
  Future<Map<String, dynamic>> activate({
    required String planName,
    required String deviceId,
  }) async {
    try {
      final online = await NetworkService.isOnline();

      if (!online) {
        return {
          'success': false,
          'message': 'Internet required to activate license',
        };
      }

      final response = await _api.post(
        '/License/activate',
        {
          'planName': planName,
          'deviceId': deviceId,
        },
      );

      final data = Map<String, dynamic>.from(response);

      await LicenseCacheService.saveLicense({
        'isActive': true,
        'isExpired': false,
        'planName': data['planName'] ?? planName,
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'daysRemaining': data['daysRemaining'] ?? 0,
      });

      return {
        'success': true,
        'mode': 'online',
        'data': data,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
