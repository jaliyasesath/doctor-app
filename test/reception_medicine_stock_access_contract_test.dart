import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) => File(relativePath).readAsStringSync();

  test('reception dashboard exposes medicine stock', () {
    final dashboard = source(
      'lib/features/reception/screens/reception_dashboard_screen.dart',
    );

    expect(dashboard, contains("'Medicine Stock'"));
    expect(dashboard, contains('const MedicineStockScreen()'));
  });

  test('reception dashboard lists pending patients and opens dispense', () {
    final dashboard = source(
      'lib/features/reception/screens/reception_dashboard_screen.dart',
    );
    final stock = source(
      'lib/features/stock/screens/medicine_stock_screen.dart',
    );

    expect(dashboard, contains('allPendingPrescriptions()'));
    expect(dashboard, contains("prescription['patientName']"));
    expect(dashboard, contains('Waiting to Dispense'));
    expect(dashboard, contains('initialPrescriptionId: id'));
    expect(dashboard, contains('openDispenseOnStart: true'));
    expect(stock, contains('final int? initialPrescriptionId;'));
    expect(stock, contains('final bool openDispenseOnStart;'));
    expect(stock, contains('_dispense(initialPrescriptionId:'));
  });

  test('reception stock access remains restricted to dispensing', () {
    final stock = source(
      'lib/features/stock/screens/medicine_stock_screen.dart',
    );

    expect(stock, contains("role.toLowerCase() == 'doctor'"));
    expect(stock, contains("value == 'dispense'"));
    expect(stock, contains('if (_canManageStock)'));
    expect(stock, contains('floatingActionButton: _canManageStock'));
    expect(
        stock, contains('onTap: _canManageStock ? () => _adjust(item) : null'));
  });
}
