import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template screens isolate Windows and mobile presentation', () {
    const files = <String>[
      'lib/features/template/screens/template_list_screen.dart',
      'lib/features/template/screens/template_edit_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains(
          'Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000',
        ),
      );
      expect(source, contains('return Scaffold('));
    }
  });

  test('template dialogs use the active workspace navigator', () {
    const files = <String>[
      'lib/features/template/screens/template_list_screen.dart',
      'lib/features/template/screens/template_edit_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      final dialogCount = RegExp(r'showDialog<').allMatches(source).length;
      final scopedCount = RegExp(
        r'showDialog<[\s\S]*?useRootNavigator:\s*false,',
      ).allMatches(source).length;
      expect(scopedCount, dialogCount);
    }
  });

  test('template decoding safely handles invalid stored JSON', () {
    final source = File(
      'lib/features/template/data/template_service.dart',
    ).readAsStringSync();

    expect(source, contains('if (decoded is! List) return [];'));
    expect(source, contains('on FormatException'));
  });
}
