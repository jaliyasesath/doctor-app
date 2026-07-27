class DoctorModel {
  final int? id;
  final String doctorName;
  final String contactNumber;
  final String email;
  final String city;
  final String specialization;
  final String medicalCenterName;
  final String clinicAddress;
  final String password;
  final bool biometricEnabled;
  final String createdAt;

  DoctorModel({
    this.id,
    required this.doctorName,
    required this.contactNumber,
    required this.email,
    required this.city,
    required this.specialization,
    required this.medicalCenterName,
    required this.clinicAddress,
    required this.password,
    required this.biometricEnabled,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_name': doctorName,
      'contact_number': contactNumber,
      'email': email,
      'city': city,
      'specialization': specialization,
      'medical_center_name': medicalCenterName,
      'clinic_address': clinicAddress,
      'password': password,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'created_at': createdAt,
    };
  }
}
