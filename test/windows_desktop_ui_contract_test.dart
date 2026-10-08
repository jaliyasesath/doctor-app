import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop dashboard is Windows-only and mobile UI remains the fallback', () {
    final home = File(
      'lib/features/dashboard/screens/home_screen.dart',
    ).readAsStringSync();

    expect(home, contains('Platform.isWindows &&'));
    expect(home, contains('return _buildDesktopScaffold();'));
    expect(home, contains('return Scaffold('));
    expect(home, contains('DesktopHomeScreen('));
  });

  test('desktop UI reuses existing data and action callbacks', () {
    final desktop = File(
      'lib/features/dashboard/screens/desktop_home_screen.dart',
    ).readAsStringSync();

    expect(desktop, contains('required this.queueSummary'));
    expect(desktop, contains('required this.todayIncome'));
    expect(desktop, contains('required this.onNavigate'));
    expect(desktop, contains('required this.onSync'));
    expect(desktop, contains("onNavigate('Create Prescription')"));
    expect(desktop, contains("onNavigate('Patient Master')"));
  });
}
