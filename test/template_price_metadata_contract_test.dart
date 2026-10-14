import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved prescription templates retain billing metadata', () {
    final source = File(
      'lib/features/prescription/screens/prescription_list_screen.dart',
    ).readAsStringSync();

    for (final field in <String>[
      "'medicine_id': e.medicineId",
      "'prescription_only': e.prescriptionOnly",
      "'unit_price': e.unitPrice",
      "'quantity': e.quantity",
      "'line_total': e.lineTotal",
    ]) {
      expect(source, contains(field));
    }
  });

  test('both template apply paths restore billing metadata', () {
    final prescriptionSource = File(
      'lib/features/prescription/screens/prescription_list_screen.dart',
    ).readAsStringSync();
    final listSource = File(
      'lib/features/template/screens/template_list_screen.dart',
    ).readAsStringSync();

    for (final source in <String>[prescriptionSource, listSource]) {
      expect(
        source,
        anyOf(contains("item['unit_price']"), contains("e['unit_price']")),
      );
      expect(source, contains('unitPrice:'));
      expect(source, contains('quantity:'));
      expect(source, contains('lineTotal:'));
      expect(source, contains('prescriptionOnly:'));
    }
  });

  test('editing a template medicine preserves hidden billing fields', () {
    final source = File(
      'lib/features/template/screens/template_edit_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'unit_price': existing?['unit_price'] ?? 0"));
    expect(source, contains("'quantity': existing?['quantity'] ?? 1"));
    expect(source, contains("'line_total': existing?['line_total']"));
  });
}
