import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../models/prescription_item.dart';

class PrescriptionStore {
  static List<PrescriptionItem> items = [];

  static String patientName = '';
  static String patientAge = '';
  static String patientGender = '';
  static String patientPhoneNumber = '';
  static String patientAddress = '';
  static String patientNotes = '';

  static String complaint = '';
  static String diagnosis = '';
  static String visitNotes = '';

  static double consultationFee = 1500.0;

  static void add(PrescriptionItem item) {
    items.add(item);
  }

  static void setItems(List<PrescriptionItem> newItems) {
    items = List<PrescriptionItem>.from(newItems);
  }

  static void setConsultationFee(double fee) {
    consultationFee = fee;
  }

  static void clearConsultationFee() {
    consultationFee = 1500.0;
  }

  static void clear() {
    items.clear();
    patientName = '';
    patientAge = '';
    patientGender = '';
    patientPhoneNumber = '';
    patientAddress = '';
    patientNotes = '';
    complaint = '';
    diagnosis = '';
    visitNotes = '';
    consultationFee = 1500.0;
  }

  static void setPatientDetails({
    required String name,
    required String age,
    required String gender,
    String phoneNumber = '',
    String address = '',
    String notes = '',
  }) {
    patientName = name;
    patientAge = age;
    patientGender = gender;
    patientPhoneNumber = phoneNumber;
    patientAddress = address;
    patientNotes = notes;
  }

  static void setClinicalDetails({
    String complaintText = '',
    String diagnosisText = '',
    String visitNotesText = '',
  }) {
    complaint = complaintText;
    diagnosis = diagnosisText;
    visitNotes = visitNotesText;
  }

  static Future<String> generatePersistentRxNumber() async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();

    if (doctorId == null || doctorId <= 0) {
      throw Exception('Doctor session not found for Rx number generation');
    }

    final year = DateTime.now().year;
    final prefs = await SharedPreferences.getInstance();
    final counterKey = 'last_rx_number_${doctorId}_$year';

    final savedNumber = prefs.getInt(counterKey) ?? 0;
    final databaseNumber =
        await DatabaseHelper.instance.getLastPrescriptionSequence(
      doctorId: doctorId,
      year: year,
    );

    final lastNumber = savedNumber > databaseNumber
        ? savedNumber
        : databaseNumber;
    final nextNumber = lastNumber + 1;

    await prefs.setInt(counterKey, nextNumber);

    return '$year-${nextNumber.toString().padLeft(4, '0')}';
  }
}
