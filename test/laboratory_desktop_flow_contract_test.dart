import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('laboratory and reports desktop layouts are Windows isolated', () {
    for (final path in [
      'lib/features/lab/screens/laboratory_list_screen.dart',
      'lib/features/lab/screens/patient_lab_reports_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('Platform.isWindows'));
      expect(source, contains('MediaQuery.sizeOf(context).width >= 1000'));
      expect(source, contains('return Scaffold('));
    }
  });

  test('existing laboratory and report operations reach desktop views', () {
    final labs = File(
      'lib/features/lab/screens/laboratory_list_screen.dart',
    ).readAsStringSync();
    expect(labs, contains('onRefresh: _load'));
    expect(labs, contains('onEdit: _edit'));
    expect(labs, contains('onDelete: _delete'));
    expect(labs, contains('onTestEmail: _testEmail'));

    final reports = File(
      'lib/features/lab/screens/patient_lab_reports_screen.dart',
    ).readAsStringSync();
    expect(reports, contains('onOpen: _open'));
    expect(reports, contains('onReview: _review'));
    expect(reports, contains('onLoadMore: _loadMore'));
  });

  test('laboratory overlays stay inside the desktop workspace navigator', () {
    for (final path in [
      'lib/features/lab/screens/laboratory_list_screen.dart',
      'lib/features/lab/screens/patient_lab_reports_screen.dart',
      'lib/features/lab/screens/create_lab_order_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final dialogs = RegExp(r'showDialog<').allMatches(source).length;
      final scoped = RegExp(
        r'showDialog<[\s\S]*?useRootNavigator:\s*false,',
      ).allMatches(source).length;
      expect(scoped, dialogs, reason: '$path has an unscoped dialog');
    }
  });
}
