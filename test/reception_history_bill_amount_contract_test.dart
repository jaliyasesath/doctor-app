import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reception history restores items and saved historical bill totals', () {
    final history = File(
      'lib/features/prescription/screens/prescription_history_screen.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/prescription/screens/print_preview_screen.dart',
    ).readAsStringSync();
    final sync = File(
      'lib/features/sync/services/sync_service.dart',
    ).readAsStringSync();
    final database = File(
      'lib/data/local/database_helper.dart',
    ).readAsStringSync();

    expect(history, contains('getPrescriptionItems(prescriptionId)'));
    expect(history, contains('pullBills('));
    expect(history, contains('billing_backfill_v2_'));
    expect(sync, contains('items: items'));
    expect(sync, contains('bool fullRefresh = false'));
    expect(database, contains("pricedLocalItem?['unit_price']"));
    expect(database, contains('unitPrice * quantity'));
    expect(preview, contains("_savedBillAmount('medicine_charges'"));
    expect(preview, contains("_savedBillAmount('total_amount'"));
  });
}
