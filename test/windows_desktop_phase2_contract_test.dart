import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patient and queue desktop views are Windows-only', () {
    final patients = File(
      'lib/features/patient/screens/patient_master_screen.dart',
    ).readAsStringSync();
    final queue = File(
      'lib/features/queue/screens/doctor_queue_screen.dart',
    ).readAsStringSync();

    expect(patients, contains('Platform.isWindows &&'));
    expect(patients, contains('DesktopPatientMasterView('));
    expect(queue, contains('Platform.isWindows &&'));
    expect(queue, contains('DesktopDoctorQueueView('));
  });

  test('existing data operations are passed to desktop presentation', () {
    final patients = File(
      'lib/features/patient/screens/patient_master_screen.dart',
    ).readAsStringSync();
    final queue = File(
      'lib/features/queue/screens/doctor_queue_screen.dart',
    ).readAsStringSync();

    expect(patients, contains('onDelete: _confirmDelete'));
    expect(patients, contains('onEdit: _openEditScreen'));
    expect(patients, contains('onSearchChanged: _handleSearchChanged'));
    expect(queue, contains('onSkip: _skipPatient'));
    expect(queue, contains('onComplete: _completePatient'));
    expect(queue, contains('onMoveToToday: _movePatientToToday'));
  });
}
