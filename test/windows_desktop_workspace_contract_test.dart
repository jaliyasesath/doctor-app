import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows uses one permanent workspace and nested content navigator', () {
    final source = File(
      'lib/core/widgets/desktop_workspace_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class DesktopWorkspaceScreen'));
    expect(source, contains('GlobalKey<NavigatorState>'));
    expect(source, contains('Navigator('));
    expect(source, contains('pushReplacement'));
    expect(source, contains("_DesktopNavItem('Dashboard'"));
    expect(source, contains("_DesktopNavItem('Today Queue'"));
    expect(source, contains("_DesktopNavItem('Patients'"));
    expect(source, contains("_DesktopNavItem('Doctor Profile'"));
  });

  test('desktop failures are logged without displaying exception details', () {
    final source = File(
      'lib/core/widgets/desktop_workspace_screen.dart',
    ).readAsStringSync();

    expect(source, contains('AppErrorHandler.recordUnawaited'));
    expect(source, contains("source: 'DesktopNavigation'"));
    expect(source, contains("source: 'DesktopModuleBuild'"));
    expect(source,
        contains('This section could not be opened. Please retry.'));
  });

  test('mobile remains outside the desktop workspace boundary', () {
    final home = File(
      'lib/features/dashboard/screens/home_screen.dart',
    ).readAsStringSync();

    expect(home, contains('Platform.isWindows &&'));
    expect(home, contains('DesktopWorkspaceScreen('));
    expect(home, contains('bottomNavigationBar: _licenseValid'));
  });
}
