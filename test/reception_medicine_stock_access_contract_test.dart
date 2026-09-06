import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) =>
      File(relativePath).readAsStringSync();

  test('reception dashboard exposes medicine stock', () {
    final dashboard = source(
      'lib/features/reception/screens/reception_dashboard_screen.dart',
    );

    expect(dashboard, contains("title: 'Medicine Stock'"));
    expect(dashboard, contains('const MedicineStockScreen()'));
  });

  test('reception stock access remains restricted to dispensing', () {
    final stock = source(
      'lib/features/stock/screens/medicine_stock_screen.dart',
    );

    expect(stock, contains("role.toLowerCase() == 'doctor'"));
    expect(stock, contains("value == 'dispense'"));
    expect(stock, contains('if (_canManageStock)'));
    expect(stock, contains('floatingActionButton: _canManageStock'));
    expect(stock, contains('onTap: _canManageStock ? () => _adjust(item) : null'));
  });
}
