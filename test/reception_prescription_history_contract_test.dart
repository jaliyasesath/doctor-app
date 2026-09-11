import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reception history is linked-doctor scoped and server refreshed', () {
    final source = File(
      'lib/features/prescription/screens/prescription_history_screen.dart',
    ).readAsStringSync();

    expect(source, contains('getActiveDoctorIdForData()'));
    expect(source, contains('getPrescriptionsByDoctorPaged('));
    expect(source, isNot(contains('DatabaseHelper.instance.getPrescriptions()')));
    expect(source, contains('_refreshReceptionHistoryFromServer'));
    expect(source, contains('reception_prescription_history_backfill_v1_'));
    expect(source, contains('fullRefresh: needsFullBackfill'));
  });
}
