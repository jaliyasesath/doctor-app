import 'package:shared_preferences/shared_preferences.dart';
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

  static void add(PrescriptionItem item) {
    items.add(item);
  }

  static void setItems(List<PrescriptionItem> newItems) {
    items = List<PrescriptionItem>.from(newItems);
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
    final prefs = await SharedPreferences.getInstance();

    final int lastNumber = prefs.getInt('last_rx_number') ?? 0;
    final int nextNumber = lastNumber + 1;

    await prefs.setInt('last_rx_number', nextNumber);

    final int year = DateTime.now().year;
    return '$year-${nextNumber.toString().padLeft(4, '0')}';
  }
}