import '../../../data/local/database_helper.dart';
import '../../../core/errors/api_error_classifier.dart';
import '../../../core/errors/app_exception.dart';
import '../../../features/net_service/api_client.dart';
import '../../../features/net_service/token_storage.dart';
import '../../license/data/license_cache_service.dart';
import '../../net_service/network_service.dart';
import 'credential_storage.dart';
import 'doctor_session.dart';
import 'login_error_policy.dart';

class ApiAuthService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> register({
    required String doctorName,
    required String email,
    required String password,
    required String contactNumber,
    required String specialization,
    required String role,

    String qualifications = '',
    String profession = '',
    String slmcRegNo = '',
    String affiliation = '',
    String linkedDoctorEmail = '',
    String signaturePath = '',

    String medicalCenterName = '',
    String city = '',
    String clinicAddress = '',
    int biometricEnabled = 0,
    bool saveLocal = true,
  }) async {
    try {
      final existing = await DatabaseHelper.instance.getDoctorByEmail(email);

      if (saveLocal && existing != null) {
        return {
          'success': false,
          'message': 'Email already registered locally',
        };
      }

      final online = await NetworkService.isOnline();
      int serverId = 0;

      if (online) {
        final response = await _api.post(
          '/Auth/register',
          {
            'doctorName': doctorName,
            'email': email,
            'password': password,
            'contactNumber': contactNumber,
            'specialization': specialization,
            'medicalCenterName': medicalCenterName,
            'role': role,
            'qualifications': qualifications,
            'profession': profession,
            'slmcRegNo': slmcRegNo,
            'affiliation': affiliation,
            'linkedDoctorEmail': linkedDoctorEmail,
            'signaturePath': signaturePath,
          },
          auth: false,
        );

        serverId = _extractServerDoctorId(response);
      }

      int localDoctorId = existing?['id'] as int? ?? 0;

      if (saveLocal) {
        localDoctorId = await DatabaseHelper.instance.insertDoctor({
          'server_id': serverId == 0 ? null : serverId,
          'doctor_name': doctorName,
          'contact_number': contactNumber,
          'email': email,
          'city': city,
          'specialization': specialization,
          'role': role,
          'medical_center_name': medicalCenterName,
          'clinic_address': clinicAddress,
          'qualifications': qualifications,
          'profession': profession,
          'slmc_reg_no': slmcRegNo,
          'affiliation': affiliation,
          'signature_path': signaturePath,
          'password': '',
          'biometric_enabled': biometricEnabled,
          'sync_status': online ? 'synced' : 'pending',
          'updated_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });

        await DoctorSession.saveDoctorSession({
          'id': localDoctorId,
          'doctor_name': doctorName,
          'email': email,
          'password': password,
          'contact_number': contactNumber,
          'specialization': specialization,
          'role': role,
          'medical_center_name': medicalCenterName,
          'clinic_address': clinicAddress,
          'qualifications': qualifications,
          'profession': profession,
          'slmc_reg_no': slmcRegNo,
          'affiliation': affiliation,
          'signature_path': signaturePath,
          'biometric_enabled': biometricEnabled,
        });

        final doctorId = await DoctorSession.getDoctorId();

        if (doctorId != null) {
          await DatabaseHelper.instance.assignOldLocalDataToDoctor(doctorId);
        }

        await LicenseCacheService.saveLicense({
          'isActive': true,
          'isExpired': false,
          'planName': online ? 'Trial' : 'Offline Trial',
          'startDate': DateTime.now().toIso8601String(),
          'endDate': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
          'daysRemaining': 30,
        });
      }

      return {
        'success': true,
        'mode': online ? 'online' : 'offline',
        'serverId': serverId,
        'doctorId': serverId,
        'localDoctorId': localDoctorId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  int _extractServerDoctorId(dynamic response) {
    if (response is Map<String, dynamic>) {
      final value = response['serverId'] ??
          response['doctorId'] ??
          response['id'] ??
          response['data']?['id'] ??
          response['doctor']?['id'];

      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final deviceId = await TokenStorage.getOrCreateDeviceId();
      final response = await _api.post(
        '/Auth/login',
        {
          'email': email,
          'password': password,
          'deviceId': deviceId,
        },
        auth: false,
      );

      if (response is! Map<String, dynamic>) {
        throw ApiErrorClassifier.invalidResponse(
          operation: 'POST /Auth/login',
        );
      }

      final token = response['token']?.toString() ?? '';
      final refreshToken = response['refreshToken']?.toString() ?? '';
      final doctorValue = response['doctor'];

      if (doctorValue is! Map) {
        throw ApiErrorClassifier.invalidResponse(
          operation: 'POST /Auth/login',
        );
      }

      final doctor = Map<String, dynamic>.from(doctorValue);

      if (token.isEmpty || refreshToken.isEmpty) {
        throw ApiErrorClassifier.invalidResponse(
          operation: 'POST /Auth/login',
        );
      }

      await TokenStorage.saveTokenPair(
        accessToken: token,
        refreshToken: refreshToken,
      );
      await CredentialStorage.savePassword(email, password);

      final existing = await DatabaseHelper.instance.getDoctorByEmail(email);

      int localDoctorId;

      if (existing == null) {
        localDoctorId = await DatabaseHelper.instance.insertDoctor({
          'server_id': doctor['id'],
          'doctor_name': doctor['doctorName'] ?? '',
          'contact_number': doctor['contactNumber'] ?? '',
          'email': doctor['email'] ?? '',
          'city': '',
          'specialization': doctor['specialization'] ?? '',
          'role': doctor['role'] ?? doctor['Role'] ?? 'Doctor',
          'medical_center_name': doctor['medicalCenterName'] ?? '',
          'clinic_address': doctor['clinicAddress'] ?? '',
          'qualifications': doctor['qualifications'] ?? '',
          'profession': doctor['profession'] ?? '',
          'slmc_reg_no': doctor['slmcRegNo'] ?? '',
          'affiliation': doctor['affiliation'] ?? '',
          'signature_path': doctor['signaturePath'] ?? '',
          'password': '',
          'biometric_enabled': 0,
          'sync_status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        localDoctorId = existing['id'] as int;
      }

      final localDb = await DatabaseHelper.instance.database;
      await localDb.update(
        'doctors',
        {'password': ''},
        where: 'id = ?',
        whereArgs: [localDoctorId],
      );

      await DoctorSession.saveDoctorSession({
        'id': localDoctorId,
        'doctor_name': doctor['doctorName'] ?? '',
        'email': doctor['email'] ?? '',
        'password': password,
        'contact_number': doctor['contactNumber'] ?? '',
        'specialization': doctor['specialization'] ?? '',
        'role': doctor['role'] ?? doctor['Role'] ?? existing?['role'] ?? 'Doctor',
        'medical_center_name': doctor['medicalCenterName'] ?? '',
        'clinic_address': doctor['clinicAddress'] ?? '',
        'qualifications':
            existing?['qualifications'] ?? doctor['qualifications'] ?? '',
        'profession': existing?['profession'] ?? doctor['profession'] ?? '',
        'slmc_reg_no': existing?['slmc_reg_no'] ?? doctor['slmcRegNo'] ?? '',
        'affiliation': existing?['affiliation'] ?? doctor['affiliation'] ?? '',
        'signature_path':
            existing?['signature_path'] ?? doctor['signaturePath'] ?? '',
        'biometric_enabled': existing?['biometric_enabled'] ?? 0,
      });

      final doctorId = await DoctorSession.getDoctorId();

      if (doctorId != null) {
        await DatabaseHelper.instance.assignOldLocalDataToDoctor(doctorId);
      }

      return {
        'success': true,
        'doctor': {
          ...doctor,
          'role': doctor['role'] ?? doctor['Role'] ?? existing?['role'] ?? 'Doctor',
          'localDoctorId': localDoctorId,
        },
        'token': token,
        'mode': 'online',
      };
    } on AppException catch (error) {
      if (!LoginErrorPolicy.canAttemptOffline(error)) {
        return LoginErrorPolicy.failureResult(error);
      }

      final localDoctor = await DatabaseHelper.instance.getDoctorByEmail(email);
      var credentialMatches = await CredentialStorage.matches(email, password);
      final legacyPassword = localDoctor?['password']?.toString() ?? '';

      if (!credentialMatches &&
          legacyPassword.isNotEmpty &&
          legacyPassword == password) {
        await CredentialStorage.savePassword(email, password);
        credentialMatches = true;
      }

      if (localDoctor != null && credentialMatches) {
        final localDb = await DatabaseHelper.instance.database;
        await localDb.update(
          'doctors',
          {'password': ''},
          where: 'id = ?',
          whereArgs: [localDoctor['id']],
        );
        await DoctorSession.saveDoctorSession({
          'id': localDoctor['id'],
          'doctor_name': localDoctor['doctor_name'] ?? '',
          'email': localDoctor['email'] ?? '',
          'password': password,
          'contact_number': localDoctor['contact_number'] ?? '',
          'specialization': localDoctor['specialization'] ?? '',
          'role': localDoctor['role'] ?? 'Doctor',
          'medical_center_name': localDoctor['medical_center_name'] ?? '',
          'clinic_address': localDoctor['clinic_address'] ?? '',
          'qualifications': localDoctor['qualifications'] ?? '',
          'profession': localDoctor['profession'] ?? '',
          'slmc_reg_no': localDoctor['slmc_reg_no'] ?? '',
          'affiliation': localDoctor['affiliation'] ?? '',
          'signature_path': localDoctor['signature_path'] ?? '',
          'biometric_enabled': localDoctor['biometric_enabled'] ?? 0,
        });

        final doctorId = await DoctorSession.getDoctorId();

        if (doctorId != null) {
          await DatabaseHelper.instance.assignOldLocalDataToDoctor(doctorId);
        }

        return {
          'success': true,
          'doctor': {
            ...localDoctor,
            'role': localDoctor['role'] ?? 'Doctor',
          },
          'mode': 'offline',
        };
      }

      return {
        'success': false,
        'message':
            'Cannot connect to the server and no matching offline login was found.',
        'code': 'OFFLINE_LOGIN_UNAVAILABLE',
        'mode': 'offline',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Login could not be completed. Please try again.',
        'code': 'UNEXPECTED_LOGIN_ERROR',
      };
    }
  }

  Future<String?> getToken() async {
    return TokenStorage.getToken();
  }

  Future<void> logout() async {
    final refreshToken = await TokenStorage.getRefreshToken();

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _api.post(
          '/Auth/logout',
          {
            'refreshToken': refreshToken,
            'deviceId': await TokenStorage.getOrCreateDeviceId(),
          },
          auth: false,
        );
      } catch (_) {
        // Local logout must still work when the server is unavailable.
      }
    }

    await TokenStorage.clearToken();
    await DoctorSession.clearSession();
  }
}
