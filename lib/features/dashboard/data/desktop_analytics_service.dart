import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';

class DesktopAnalyticsSnapshot {
  const DesktopAnalyticsSnapshot({required this.summary, required this.billing,
    required this.daily, required this.topMedicines, required this.doctorId,
    required this.from, required this.to});
  final Map<String, Object?> summary;
  final Map<String, Object?> billing;
  final List<Map<String, Object?>> daily;
  final List<Map<String, Object?>> topMedicines;
  final int doctorId;
  final DateTime from;
  final DateTime to;
  num value(Map<String, Object?> row, String key) =>
      row[key] is num ? row[key] as num : num.tryParse('${row[key] ?? 0}') ?? 0;
  bool get empty => value(summary, 'prescriptions') == 0 &&
      value(summary, 'new_patients') == 0 && value(billing, 'bills') == 0;
}

/// Summaries only; never loads patient identifiers or clinical notes into UI.
/// Calendar dates follow the stored YYYY-MM-DD date prefix, as existing billing.
class DesktopAnalyticsService {
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // Bound parameters: doctor ID, inclusive start day, exclusive end day.
  // ISO-prefix comparisons keep the doctor's date index useful for range scans.
  static const prescriptionSummary = '''
SELECT COUNT(*) AS prescriptions, COUNT(DISTINCT patient_id) AS patients
FROM prescriptions
WHERE doctor_id = ? AND COALESCE(is_deleted, 0) = 0
AND prescription_date >= ? AND prescription_date < ?
''';
  static const patientSummary = '''
SELECT COUNT(*) AS new_patients FROM patients
WHERE doctor_id = ? AND COALESCE(is_deleted, 0) = 0
AND created_at >= ? AND created_at < ?
''';
  static const billingSummary = '''
SELECT COUNT(*) AS bills, COALESCE(SUM(total_amount),0) AS billed,
COALESCE(SUM(paid_amount),0) AS collected,
COALESCE(SUM(balance_amount),0) AS outstanding,
COALESCE(SUM(consultation_fee),0) AS consultation,
COALESCE(SUM(medicine_charges),0) AS medicine_charges
FROM prescription_bills
WHERE doctor_id = ? AND COALESCE(is_deleted, 0) = 0
AND created_at >= ? AND created_at < ?
''';
  static const dailyPrescriptions = '''
SELECT substr(prescription_date,1,10) AS day, COUNT(*) AS prescriptions,
COUNT(DISTINCT patient_id) AS patients
FROM prescriptions
WHERE doctor_id = ? AND COALESCE(is_deleted, 0) = 0
AND prescription_date >= ? AND prescription_date < ?
GROUP BY substr(prescription_date,1,10) ORDER BY day
''';
  static const dailyBilling = '''
SELECT substr(created_at,1,10) AS day,
COALESCE(SUM(total_amount),0) AS billed,
COALESCE(SUM(paid_amount),0) AS collected
FROM prescription_bills
WHERE doctor_id = ? AND COALESCE(is_deleted, 0) = 0
AND created_at >= ? AND created_at < ?
GROUP BY substr(created_at,1,10) ORDER BY day
''';
  static const medicineSummary = '''
SELECT COUNT(DISTINCT lower(trim(i.medicine_name))) AS prescribed_medicines,
COUNT(*) AS medicine_lines
FROM prescription_items i JOIN prescriptions p ON p.id = i.prescription_id
WHERE p.doctor_id = ? AND COALESCE(p.is_deleted,0) = 0
AND p.prescription_date >= ? AND p.prescription_date < ?
AND i.medicine_name IS NOT NULL AND trim(i.medicine_name) != ''
''';
  static const topMedicineQuery = '''
SELECT MIN(trim(i.medicine_name)) AS name, COUNT(*) AS lines,
COUNT(DISTINCT p.id) AS prescriptions
FROM prescription_items i JOIN prescriptions p ON p.id = i.prescription_id
WHERE p.doctor_id = ? AND COALESCE(p.is_deleted,0) = 0
AND p.prescription_date >= ? AND p.prescription_date < ?
AND i.medicine_name IS NOT NULL AND trim(i.medicine_name) != ''
GROUP BY lower(trim(i.medicine_name)) ORDER BY lines DESC, name ASC LIMIT 10
''';

  Future<DesktopAnalyticsSnapshot> load(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final finish = DateTime(to.year, to.month, to.day);
    // UTC calendar arithmetic avoids DST-sensitive day counts.
    final dayCount = DateTime.utc(finish.year, finish.month, finish.day)
        .difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
    if (dayCount < 1 || dayCount > 366) {
      throw ArgumentError('Choose an inclusive date range of 1–366 days.');
    }
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    if (doctorId == null || doctorId <= 0) {
      throw StateError('A signed-in doctor account is required.');
    }
    final args = <Object?>[doctorId, dateKey(start),
      dateKey(DateTime(finish.year, finish.month, finish.day + 1))];
    final db = await DatabaseHelper.instance.database;
    final snapshot = await db.transaction((txn) async {
      final summary = Map<String, Object?>.from((await txn.rawQuery(prescriptionSummary, args)).first);
      summary.addAll((await txn.rawQuery(patientSummary, args)).first);
      summary.addAll((await txn.rawQuery(medicineSummary, args)).first);
      final billing = (await txn.rawQuery(billingSummary, args)).first;
      final rx = await txn.rawQuery(dailyPrescriptions, args);
      final income = await txn.rawQuery(dailyBilling, args);
      final top = await txn.rawQuery(topMedicineQuery, args);
      final rxDays = {for (final row in rx) row['day']: row};
      final incomeDays = {for (final row in income) row['day']: row};
      final daily = <Map<String, Object?>>[];
      for (var index = 0; index < dayCount; index++) {
        final day = dateKey(DateTime(start.year, start.month, start.day + index));
        daily.add({'day': day, 'prescriptions': rxDays[day]?['prescriptions'] ?? 0,
          'patients': rxDays[day]?['patients'] ?? 0,
          'billed': incomeDays[day]?['billed'] ?? 0,
          'collected': incomeDays[day]?['collected'] ?? 0});
      }
      return DesktopAnalyticsSnapshot(summary: summary, billing: billing,
        daily: daily, topMedicines: top, doctorId: doctorId, from: start, to: finish);
    }, exclusive: false);
    // Prevent an async result from being presented under a different session.
    if (await DoctorSession.getActiveDoctorIdForData() != doctorId) {
      throw StateError('The account changed while loading analytics.');
    }
    return snapshot;
  }
}
