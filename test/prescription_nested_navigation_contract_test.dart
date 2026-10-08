import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prescription dialogs stay inside the active workspace navigator', () {
    const files = <String>[
      'lib/features/prescription/widgets/smart_chips_section.dart',
      'lib/features/prescription/screens/prescription_list_screen.dart',
      'lib/features/prescription/screens/prescription_history_screen.dart',
      'lib/features/prescription/screens/print_preview_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      final dialogCount = RegExp(r'showDialog<').allMatches(source).length;
      final scopedDialogCount = RegExp(
        r'showDialog<[\s\S]*?useRootNavigator:\s*false,',
      ).allMatches(source).length;

      expect(
        scopedDialogCount,
        dialogCount,
        reason: '$path contains a dialog that can escape the desktop workspace',
      );
    }
  });

  test('custom clinical chip dialogs close their own dialog context', () {
    const files = <String>[
      'lib/features/prescription/widgets/smart_chips_section.dart',
      'lib/features/prescription/screens/prescription_list_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('builder: (dialogContext)'));
      expect(source, contains('Navigator.pop(dialogContext'));
    }
  });
}
