import 'package:doctor_app/features/stock/domain/stock_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Medicine stock validation', () {
    test('accepts a valid stock receipt', () {
      expect(
        StockValidation.receive(
          batchNumber: 'B-100',
          quantity: 25,
          costPrice: 10,
          sellingPrice: 15,
          expiryDate: DateTime(2027, 1, 1),
          now: DateTime(2026, 8, 3),
        ),
        isNull,
      );
    });

    test('rejects expired stock', () {
      expect(
        StockValidation.receive(
          batchNumber: 'B-100',
          quantity: 25,
          costPrice: 10,
          sellingPrice: 15,
          expiryDate: DateTime(2026, 8, 2),
          now: DateTime(2026, 8, 3),
        ),
        'Expired stock cannot be received.',
      );
    });

    test('rejects empty adjustment reason', () {
      expect(
        StockValidation.adjustment(quantity: 1, reason: ' '),
        'Adjustment reason is required.',
      );
    });

    test('rejects zero adjustment quantity', () {
      expect(
        StockValidation.adjustment(quantity: 0, reason: 'Physical count'),
        'Quantity must be greater than zero.',
      );
    });

    test('accepts a valid adjustment', () {
      expect(
        StockValidation.adjustment(quantity: 2, reason: 'Physical count'),
        isNull,
      );
    });
  });
}
