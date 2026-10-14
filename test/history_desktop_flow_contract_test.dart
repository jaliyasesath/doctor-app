import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history desktop layouts are Windows-gated', () {
    for (final path in [
      'lib/features/prescription/screens/prescription_history_screen.dart',
      'lib/features/prescription/screens/patient_history_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('Platform.isWindows'));
      expect(source, contains('MediaQuery.sizeOf(context).width >= 1000'));
    }
  });

  test('existing history operations are passed to desktop presentation', () {
    final prescription = File(
      'lib/features/prescription/screens/prescription_history_screen.dart',
    ).readAsStringSync();
    expect(prescription, contains('onRefresh: _refresh'));
    expect(prescription, contains('onOpen: _open'));
    expect(prescription, contains('onDelete: _confirmDelete'));
    expect(prescription, contains('onLoadMore: _loadMorePrescriptions'));

    final patient = File(
      'lib/features/prescription/screens/patient_history_screen.dart',
    ).readAsStringSync();
    expect(patient, contains('onSearchChanged: _onSearchChanged'));
    expect(patient, contains('onOpenPatient: _openPatientProfile'));
    expect(patient, contains('onLoadMore: _loadMore'));
  });

  test('desktop history dialogs stay inside nested workspace navigator', () {
    final source = File(
      'lib/features/prescription/screens/prescription_history_screen.dart',
    ).readAsStringSync();
    expect(source, contains('useRootNavigator: false'));
  });

  test('patient history open and repeat preserve medicine billing metadata', () {
    final source = File(
      'lib/features/prescription/screens/patient_profile_screen.dart',
    ).readAsStringSync();
    expect(source, contains('getPrescriptionItems(prescriptionId)'));
    expect(source, contains("storedItem['unit_price']"));
    expect(source, contains("storedItem['quantity']"));
    expect(source, contains("storedItem['line_total']"));
    expect(source, contains('storedLineTotal > 0'));
  });
}
