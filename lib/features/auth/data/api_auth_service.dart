import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../data/local/database_helper.dart';
import '../../../core/errors/api_error_classifier.dart';
import '../../../core/errors/app_exception.dart';
import '../../../features/net_service/api_client.dart';
import '../../../features/net_service/token_storage.dart';
import '../../net_service/network_service.dart';
import '../../net_service/api_config.dart';
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
    String medicalCenterLogoPath = '',
    String medicalCenterName = '',
    String city = '',
    String clinicAddress = '',
    int biometricEnabled = 0,
    bool saveLocal = true,
    required File slmcIdFront,
    required File slmcIdBack,
    String verificationDocumentType = 'SLMCIdentityCard',
    required bool doctorDeclarationAccepted,
    required bool termsAccepted,
  }) async {
    try {
      final online = await NetworkService.isOnline();
      if (!online) {
        return {
          'success': false,
          'message':
              'Internet connection is required for doctor identity verification.',
          'code': 'ONLINE_REGISTRATION_REQUIRED',
        };
      }

      final baseUrl = ApiConfig.baseUrl.trim();
      if (baseUrl.isEmpty) {
        return {
          'success': false,
          'message': 'The API server address is not configured.',
          'code': 'API_URL_REQUIRED',
        };
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/Auth/register'),
      );

      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        'doctorName': doctorName,
        'email': email,
        'password': password,
        'contactNumber': contactNumber,
        'specialization': specialization,
        'medicalCenterName': medicalCenterName,
        'qualifications': qualifications,
        'profession': profession,
        'slmcRegNo': slmcRegNo,
        'affiliation': affiliation,
        'verificationDocumentType': verificationDocumentType,
        'doctorDeclarationAccepted': doctorDeclarationAccepted.toString(),
        'termsAccepted': termsAccepted.toString(),
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'slmcIdFront',
          slmcIdFront.path,
        ),
      );

      if (signaturePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('signatureImage', signaturePath));
      }
      if (medicalCenterLogoPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('medicalCenterLogo', medicalCenterLogoPath));
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'slmcIdBack',
          slmcIdBack.path,
        ),
      );

      final streamed = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiErrorClassifier.fromHttpResponse(
          statusCode: response.statusCode,
          responseBody: response.body,
          headers: response.headers,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw ApiErrorClassifier.invalidResponse(
          operation: 'POST /Auth/register',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Registration timed out. Check the connection and try again.',
        'code': 'REGISTRATION_TIMEOUT',
      };
    } on SocketException {
      return {
        'success': false,
        'message': 'The verification server could not be reached.',
        'code': 'REGISTRATION_NETWORK_ERROR',
      };
    } on AppException catch (error) {
      return {
        'success': false,
        'message': error.userMessage,
        'code': error.code,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration could not be completed. Please try again.',
        'code': 'REGISTRATION_UNEXPECTED_ERROR',
      };
    }
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
        'role':
            doctor['role'] ?? doctor['Role'] ?? existing?['role'] ?? 'Doctor',
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
          'role':
              doctor['role'] ?? doctor['Role'] ?? existing?['role'] ?? 'Doctor',
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
