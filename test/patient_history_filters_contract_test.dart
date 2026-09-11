import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('patient directory filters are paginated and doctor scoped', () {
    final screen = source(
      'lib/features/prescription/screens/patient_history_screen.dart',
    );
    final database = source('lib/data/local/database_helper.dart');

    expect(screen, contains('searchPatientHistoryByDoctorPaged'));
    expect(screen, contains('Filter Patient History'));
    expect(screen, contains('Medical alerts only'));
    expect(screen, contains('Most visits'));
    expect(database, contains("'p.doctor_id = ?'"));
    expect(database, contains('LIMIT ? OFFSET ?'));
    expect(database, contains('COUNT(rx.id) AS visit_count'));
  });

  test('patient profile supports visit filters and complete details', () {
    final profile = source(
      'lib/features/prescription/screens/patient_profile_screen.dart',
    );
    final database = source('lib/data/local/database_helper.dart');

    expect(profile, contains('Search Rx, diagnosis, complaint or medicine'));
    expect(profile, contains('showDateRangePicker'));
    expect(profile, contains("'Clinical Assessment'"));
    expect(profile, contains("'Medicines ("));
    expect(profile, contains("'Follow-up'"));
    expect(
        database, contains('getFilteredPrescriptionsByPatientAndDoctorPaged'));
    expect(database, contains('date(prescription_date) >= date(?)'));
  });
}
