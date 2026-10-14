import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billing desktop presentation is isolated from mobile UI', () {
    final source = File(
      'lib/features/billing/screens/billing_report_screen.dart',
    ).readAsStringSync();
    expect(source, contains('Platform.isWindows'));
    expect(source, contains('MediaQuery.sizeOf(context).width >= 1000'));
    expect(source, contains('DesktopBillingReportView('));
    expect(source, contains('return Scaffold('));
  });

  test('billing report is doctor scoped, filtered and paginated', () {
    final database = File(
      'lib/data/local/database_helper.dart',
    ).readAsStringSync();
    expect(database, contains('getBillingSummaryByDoctorRange'));
    expect(database, contains('getBillsByDoctorRangePaged'));
    expect(database, contains('countBillsByDoctorRange'));
    expect(database, contains('b.doctor_id = ?'));
    expect(database, contains('LIMIT ? OFFSET ?'));
  });

  test('desktop billing callbacks preserve existing data operations', () {
    final source = File(
      'lib/features/billing/screens/billing_report_screen.dart',
    ).readAsStringSync();
    expect(source, contains('onRefresh: _loadReport'));
    expect(source, contains('onLoadMore: _loadMore'));
    expect(source, contains('onFiltersChanged: _applyFilters'));
    expect(source, contains('useRootNavigator: false'));
  });

  test('desktop billing formats stored timestamps for readable display', () {
    final source = File(
      'lib/features/billing/screens/desktop_billing_report_view.dart',
    ).readAsStringSync();
    expect(source, contains("DateFormat('dd MMM yyyy')"));
    expect(source, contains("DateFormat('hh:mm a')"));
    expect(source, contains('DateTime.tryParse(raw)'));
  });
}
