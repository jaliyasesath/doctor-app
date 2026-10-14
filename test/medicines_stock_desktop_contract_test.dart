import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('medicine and stock desktop layouts are Windows-gated', () {
    const files = <String>[
      'lib/features/medicines/screens/medicine_screen.dart',
      'lib/features/stock/screens/medicine_stock_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains(
          'Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000',
        ),
        reason: '$path must not replace the Android/iOS presentation',
      );
      expect(
  source,
  contains('Scaffold('),
  reason: '$path must retain its mobile Scaffold presentation',
);
    }
  });

  test('medicine and stock overlays stay in the workspace navigator', () {
    const files = <String>[
      'lib/features/medicines/screens/medicine_screen.dart',
      'lib/features/stock/screens/medicine_stock_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      final dialogCount = RegExp(r'showDialog<').allMatches(source).length;
      final scopedCount = RegExp(
        r'showDialog<[\s\S]*?useRootNavigator:\s*false,',
      ).allMatches(source).length;
      expect(scopedCount, dialogCount, reason: '$path has an unscoped dialog');
    }
  });

  test('desktop medicine list keeps paging and role restrictions', () {
    final source = File(
      'lib/features/medicines/screens/desktop_medicine_view.dart',
    ).readAsStringSync();

    expect(source, contains('onLoadMore();'));
    expect(source, contains('if (!isReception)'));
    expect(source, contains('onToggleFavorite'));
  });
}
