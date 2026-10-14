import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../lib/features/dashboard/data/desktop_analytics_service.dart';

void main() {
  late Database db;
  const args = [1, '2026-10-01', '2026-10-03'];

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('CREATE TABLE prescriptions(id INTEGER, doctor_id INTEGER, patient_id INTEGER, is_deleted INTEGER, prescription_date TEXT)');
    db.execute('CREATE TABLE patients(id INTEGER, doctor_id INTEGER, is_deleted INTEGER, created_at TEXT)');
    db.execute('CREATE TABLE prescription_items(prescription_id INTEGER, medicine_name TEXT)');
    db.execute('CREATE TABLE prescription_bills(doctor_id INTEGER, is_deleted INTEGER, created_at TEXT, total_amount REAL, paid_amount REAL, balance_amount REAL, consultation_fee REAL, medicine_charges REAL)');
    db.execute('''INSERT INTO prescriptions VALUES
      (1,1,10,0,'2026-10-01'),(2,1,10,0,'2026-10-02T23:59:59'),
      (3,1,11,1,'2026-10-02'),(4,2,12,0,'2026-10-02'),
      (5,1,13,0,'2026-10-03'),(6,1,14,0,'2026-09-30')''');
    db.execute('''INSERT INTO patients VALUES
      (10,1,0,'2026-10-01'),(11,1,1,'2026-10-01'),
      (12,2,0,'2026-10-01'),(13,1,0,'2026-10-03')''');
    db.execute('''INSERT INTO prescription_items VALUES
      (1,' Paracetamol '),(2,'paracetamol'),(2,'Amoxicillin'),
      (3,'DELETED'),(4,'OTHER DOCTOR'),(5,'OUT OF RANGE'),(2,' '),(2,NULL)''');
    db.execute('''INSERT INTO prescription_bills VALUES
      (1,0,'2026-10-01T09:00:00',1500,1000,500,500,1000),
      (1,0,'2026-10-02T23:59:59',500,500,0,500,0),
      (1,1,'2026-10-01',9999,9999,0,0,9999),
      (2,0,'2026-10-01',8888,8888,0,0,8888),
      (1,0,'2026-10-03',7777,7777,0,0,7777)''');
  });

  tearDown(() => db.dispose());

  test('scope and deletion filters isolate patient and prescription statistics', () {
    final rx = db.select(DesktopAnalyticsService.prescriptionSummary, args).first;
    expect(rx['prescriptions'], 2);
    expect(rx['patients'], 1);
    expect(db.select(DesktopAnalyticsService.patientSummary, args).first['new_patients'], 1);
    final other = db.select(DesktopAnalyticsService.prescriptionSummary,
        [2, '2026-10-01', '2026-10-03']).first;
    expect(other['prescriptions'], 1);
    expect(other['patients'], 1);
  });

  test('billing distinguishes billed, paid and balance amounts', () {
    final row = db.select(DesktopAnalyticsService.billingSummary, args).first;
    expect(row['bills'], 2);
    expect(row['billed'], 2000);
    expect(row['collected'], 1500);
    expect(row['outstanding'], 500);
  });

  test('the last selected day includes timestamps but excludes the following day', () {
    final rows = db.select(DesktopAnalyticsService.dailyPrescriptions, args);
    expect(rows.map((row) => row['day']).toList(), ['2026-10-01', '2026-10-02']);
    expect(rows.last['prescriptions'], 1);
    expect(db.select(DesktopAnalyticsService.dailyBilling, args).last['collected'], 500);
  });

  test('medicine ranking normalizes names and excludes deleted and foreign prescriptions', () {
    final summary = db.select(DesktopAnalyticsService.medicineSummary, args).first;
    expect(summary['prescribed_medicines'], 2);
    expect(summary['medicine_lines'], 3);
    final top = db.select(DesktopAnalyticsService.topMedicineQuery, args);
    expect(top.length, 2);
    expect(top.first['lines'], 2);
    expect(top.first['prescriptions'], 2);
  });

  test('no activity yields zero summaries and no ranked medicines', () {
    const empty = [1, '2026-11-01', '2026-11-02'];
    expect(db.select(DesktopAnalyticsService.billingSummary, empty).first['billed'], 0);
    expect(db.select(DesktopAnalyticsService.prescriptionSummary, empty).first['prescriptions'], 0);
    expect(db.select(DesktopAnalyticsService.topMedicineQuery, empty), isEmpty);
  });
}
