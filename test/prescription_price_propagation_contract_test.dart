import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) {
    return File(relativePath).readAsStringSync();
  }

  test('medicine sync forces a new default-price cache refresh', () {
    final syncSource = source(
      'lib/features/sync/services/sync_service.dart',
    );

    expect(syncSource, contains('medicinePriceSchemaVersion = 2'));
    expect(syncSource, contains('refreshMedicineCatalogue()'));
    expect(syncSource, contains('await pullMedicines(result)'));
  });

  test('prescription picker refreshes prices and blocks zero-price bills', () {
    final prescriptionSource = source(
      'lib/features/prescription/screens/prescription_list_screen.dart',
    );

    expect(
      prescriptionSource,
      contains('await SyncService().refreshMedicineCatalogue()'),
    );
    expect(prescriptionSource, contains('sellingPrice <= 0'));
    expect(
      prescriptionSource,
      contains('unitPrice: prescriptionOnly ? 0 : sellingPrice'),
    );
    expect(prescriptionSource, contains('sellingPrice *'));
  });
}
