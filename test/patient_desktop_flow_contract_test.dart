import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patient screens gate desktop UI behind the Windows breakpoint', () {
    const files = <String>[
      'lib/features/patient/screens/patient_master_screen.dart',
      'lib/features/patient/screens/add_patient_screen.dart',
      'lib/features/patient/screens/patient_edit_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains(
          'Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000',
        ),
        reason: '$path must keep mobile and desktop presentation isolated',
      );
    }
  });

  test('patient dialogs remain in the permanent workspace navigator', () {
    final addSource = File(
      'lib/features/patient/screens/add_patient_screen.dart',
    ).readAsStringSync();
    final masterSource = File(
      'lib/features/patient/screens/patient_master_screen.dart',
    ).readAsStringSync();

    expect(addSource, contains('useRootNavigator: false'));
    expect(addSource, contains('Navigator.pop(dialogContext)'));
    expect(masterSource, contains('useRootNavigator: false'));
  });

  test('mobile patient scaffolds remain available', () {
    const files = <String>[
      'lib/features/patient/screens/add_patient_screen.dart',
      'lib/features/patient/screens/patient_edit_screen.dart',
      'lib/features/patient/screens/patient_master_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('return Scaffold('));
    }
  });
}
