import 'package:shared_preferences/shared_preferences.dart';

class DoctorSession {
  static const String _doctorIdKey = 'logged_in_doctor_id';
  static const String _doctorNameKey = 'logged_in_doctor_name';
  static const String _medicalCenterKey = 'logged_in_medical_center';
  static const String _specializationKey = 'logged_in_specialization';
  static const String _clinicAddressKey = 'logged_in_clinic_address';
  static const String _emailKey = 'logged_in_email';
  static const String _passwordKey = 'logged_in_password';
  static const String _biometricEnabledKey =
      'logged_in_biometric_enabled';

  static const String _roleKey = 'logged_in_role';
  static const String _lastRoleKey = 'last_role';

  static const String _parentDoctorIdKey =
      'logged_in_parent_doctor_id';
  static const String _lastParentDoctorIdKey =
      'last_parent_doctor_id';

  static const String _contactNumberKey = 'logged_in_contact_number';
  static const String _qualificationsKey = 'logged_in_qualifications';
  static const String _professionKey = 'logged_in_profession';
  static const String _slmcRegNoKey = 'logged_in_slmc_reg_no';
  static const String _affiliationKey = 'logged_in_affiliation';

  static const String _lastDoctorIdKey = 'last_doctor_id';
  static const String _lastDoctorNameKey = 'last_doctor_name';
  static const String _lastMedicalCenterKey = 'last_medical_center';
  static const String _lastSpecializationKey =
      'last_specialization';
  static const String _lastClinicAddressKey =
      'last_clinic_address';
  static const String _lastEmailKey = 'last_email';
  static const String _lastPasswordKey = 'last_password';
  static const String _lastBiometricEnabledKey =
      'last_biometric_enabled';

  static const String _signaturePathKey =
      'logged_in_signature_path';

  static int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  static Future<void> saveDoctorSession(
    Map<String, dynamic> doctor,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final id = _parseId(
      doctor['id'] ??
          doctor['localDoctorId'] ??
          doctor['doctorId'],
    );

    if (id <= 0) {
      throw Exception('Invalid local doctor id for session');
    }

    final parentDoctorId = _parseId(
      doctor['parentDoctorId'] ??
          doctor['ParentDoctorId'] ??
          doctor['parent_doctor_id'],
    );

    final doctorName = _readString(
      doctor,
      ['doctor_name', 'doctorName'],
    );

    final medicalCenter = _readString(
      doctor,
      ['medical_center_name', 'medicalCenterName'],
    );

    final specialization = _readString(
      doctor,
      ['specialization'],
    );

    final clinicAddress = _readString(
      doctor,
      ['clinic_address', 'clinicAddress'],
    );

    final email = _readString(
      doctor,
      ['email'],
    );

    final password = _readString(
      doctor,
      ['password'],
    );

    final role = _readString(
      doctor,
      ['role', 'Role'],
    );

    final safeRole = role.isEmpty ? 'Doctor' : role;

    final contactNumber = _readString(
      doctor,
      ['contact_number', 'contactNumber'],
    );

    final qualifications = _readString(
      doctor,
      ['qualifications', 'Qualifications'],
    );

    final profession = _readString(
      doctor,
      ['profession', 'Profession'],
    );

    final slmcRegNo = _readString(
      doctor,
      ['slmc_reg_no', 'slmcRegNo', 'SLMCRegNo'],
    );

    final affiliation = _readString(
      doctor,
      ['affiliation', 'Affiliation'],
    );

    final biometricEnabled = _parseBool(
      doctor['biometric_enabled'] ??
          doctor['biometricEnabled'] ??
          0,
    );

    final signaturePath =
        doctor['signature_path']?.toString() ?? '';

    await prefs.setString(
      _signaturePathKey,
      signaturePath,
    );

    await prefs.setInt(_doctorIdKey, id);

    await prefs.setInt(
      _parentDoctorIdKey,
      parentDoctorId,
    );

    await prefs.setString(
      _doctorNameKey,
      doctorName,
    );

    await prefs.setString(
      _medicalCenterKey,
      medicalCenter,
    );

    await prefs.setString(
      _specializationKey,
      specialization,
    );

    await prefs.setString(
      _clinicAddressKey,
      clinicAddress,
    );

    await prefs.setString(
      _emailKey,
      email,
    );

    await prefs.setString(
      _passwordKey,
      password,
    );

    await prefs.setBool(
      _biometricEnabledKey,
      biometricEnabled,
    );

    await prefs.setString(
      _roleKey,
      safeRole,
    );

    await prefs.setString(
      _contactNumberKey,
      contactNumber,
    );

    await prefs.setString(
      _qualificationsKey,
      qualifications,
    );

    await prefs.setString(
      _professionKey,
      profession,
    );

    await prefs.setString(
      _slmcRegNoKey,
      slmcRegNo,
    );

    await prefs.setString(
      _affiliationKey,
      affiliation,
    );

    await prefs.setInt(
      _lastDoctorIdKey,
      id,
    );

    await prefs.setInt(
      _lastParentDoctorIdKey,
      parentDoctorId,
    );

    await prefs.setString(
      _lastDoctorNameKey,
      doctorName,
    );

    await prefs.setString(
      _lastMedicalCenterKey,
      medicalCenter,
    );

    await prefs.setString(
      _lastSpecializationKey,
      specialization,
    );

    await prefs.setString(
      _lastClinicAddressKey,
      clinicAddress,
    );

    await prefs.setString(
      _lastEmailKey,
      email,
    );

    await prefs.setString(
      _lastPasswordKey,
      password,
    );

    await prefs.setBool(
      _lastBiometricEnabledKey,
      biometricEnabled,
    );

    await prefs.setString(
      _lastRoleKey,
      safeRole,
    );
  }

  static Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _biometricEnabledKey,
      true,
    );

    await prefs.setBool(
      _lastBiometricEnabledKey,
      true,
    );
  }

  static Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _biometricEnabledKey,
      false,
    );

    await prefs.setBool(
      _lastBiometricEnabledKey,
      false,
    );
  }

  static Future<Map<String, dynamic>?> getDoctor() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getInt(_doctorIdKey);
    final email = prefs.getString(_emailKey);
    final password = prefs.getString(_passwordKey);

    if (id == null || email == null || password == null) {
      return null;
    }

    return {
      'id': id,
      'doctor_name': prefs.getString(_doctorNameKey) ?? '',
      'email': email,
      'password': password,
      'role': prefs.getString(_roleKey) ?? 'Doctor',

      'parentDoctorId':
          prefs.getInt(_parentDoctorIdKey) ?? 0,
      'parent_doctor_id':
          prefs.getInt(_parentDoctorIdKey) ?? 0,

      'contact_number':
          prefs.getString(_contactNumberKey) ?? '',
      'medical_center_name':
          prefs.getString(_medicalCenterKey) ?? '',
      'specialization':
          prefs.getString(_specializationKey) ?? '',
      'clinic_address':
          prefs.getString(_clinicAddressKey) ?? '',
      'qualifications':
          prefs.getString(_qualificationsKey) ?? '',
      'profession':
          prefs.getString(_professionKey) ?? '',
      'slmc_reg_no':
          prefs.getString(_slmcRegNoKey) ?? '',
      'affiliation':
          prefs.getString(_affiliationKey) ?? '',
      'biometric_enabled':
          (prefs.getBool(_biometricEnabledKey) ?? false)
              ? 1
              : 0,
    };
  }

  static Future<int?> getDoctorId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_doctorIdKey);
  }

  static Future<int?> getParentDoctorId() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getInt(_parentDoctorIdKey);

    if (value == null || value <= 0) {
      return null;
    }

    return value;
  }

  static Future<int?> getActiveDoctorIdForData() async {
    final role = await getRole();
    final doctorId = await getDoctorId();

    if (role.toLowerCase() == 'reception') {
      final parentDoctorId = await getParentDoctorId();
      return parentDoctorId ?? doctorId;
    }

    return doctorId;
  }

  static Future<String> getDoctorName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_doctorNameKey) ?? '';
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_roleKey) ?? 'Doctor';
  }

  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_emailKey) ?? '';
  }

  static Future<String> getContactNumber() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_contactNumberKey) ?? '';
  }

  static Future<String> getMedicalCenterName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_medicalCenterKey) ?? '';
  }

  static Future<String> getSpecialization() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_specializationKey) ?? '';
  }

  static Future<String> getClinicAddress() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_clinicAddressKey) ?? '';
  }

  static Future<String> getQualifications() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_qualificationsKey) ?? '';
  }

  static Future<String> getProfession() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_professionKey) ?? '';
  }

  static Future<String> getSLMCRegNo() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_slmcRegNoKey) ?? '';
  }

  static Future<String> getAffiliation() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_affiliationKey) ?? '';
  }

  static Future<Map<String, dynamic>> getDoctorStamp() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'doctor_name':
          prefs.getString(_doctorNameKey) ?? '',
      'qualifications':
          prefs.getString(_qualificationsKey) ?? '',
      'profession':
          prefs.getString(_professionKey) ?? '',
      'slmc_reg_no':
          prefs.getString(_slmcRegNoKey) ?? '',
      'affiliation':
          prefs.getString(_affiliationKey) ?? '',
      'contact_number':
          prefs.getString(_contactNumberKey) ?? '',
      'signature_path':
          prefs.getString(_signaturePathKey) ?? '',
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_doctorIdKey);
    await prefs.remove(_parentDoctorIdKey);
    await prefs.remove(_doctorNameKey);
    await prefs.remove(_medicalCenterKey);
    await prefs.remove(_specializationKey);
    await prefs.remove(_clinicAddressKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_contactNumberKey);
    await prefs.remove(_qualificationsKey);
    await prefs.remove(_professionKey);
    await prefs.remove(_slmcRegNoKey);
    await prefs.remove(_affiliationKey);
    await prefs.remove(_signaturePathKey);
  }

  static Future<Map<String, dynamic>?>
      getLastDoctorForBiometric() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getInt(_lastDoctorIdKey);

    if (id == null) return null;

    return {
      'id': id,
      'parentDoctorId':
          prefs.getInt(_lastParentDoctorIdKey) ?? 0,
      'parent_doctor_id':
          prefs.getInt(_lastParentDoctorIdKey) ?? 0,
      'doctor_name':
          prefs.getString(_lastDoctorNameKey) ?? '',
      'medical_center_name':
          prefs.getString(_lastMedicalCenterKey) ?? '',
      'specialization':
          prefs.getString(_lastSpecializationKey) ?? '',
      'clinic_address':
          prefs.getString(_lastClinicAddressKey) ?? '',
      'email':
          prefs.getString(_lastEmailKey) ?? '',
      'password':
          prefs.getString(_lastPasswordKey) ?? '',
      'role':
          prefs.getString(_lastRoleKey) ?? 'Doctor',
      'biometric_enabled':
          (prefs.getBool(_lastBiometricEnabledKey) ?? false)
              ? 1
              : 0,
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.containsKey(_doctorIdKey);
  }
}