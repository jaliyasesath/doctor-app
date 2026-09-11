import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) => File(relativePath).readAsStringSync();

  test('doctor dashboard refreshes queue on realtime and app resume', () {
    final dashboard = source(
      'lib/features/dashboard/screens/home_screen.dart',
    );
    final realtime = source(
      'lib/features/queue/services/queue_realtime_service.dart',
    );

    expect(dashboard, contains('with WidgetsBindingObserver'));
    expect(dashboard, contains('AppLifecycleState.resumed'));
    expect(dashboard, contains('QueueRealtimeService.instance.connect()'));
    expect(dashboard, contains('_queueSummaryLoading'));
    expect(realtime, contains("'action': 'reconnected'"));
    expect(realtime, contains('_syncThenEmit'));
  });

  test('reception registration omits clinical fields without API changes', () {
    final form = source(
      'lib/features/patient/screens/add_patient_screen.dart',
    );

    expect(form, isNot(contains("label: 'Allergies'")));
    expect(form, isNot(contains("label: 'Chronic Diseases'")));
    expect(form, isNot(contains("label: 'Important Alerts'")));
    expect(form, contains("allergies: ''"));
    expect(form, contains("chronicDiseases: ''"));
    expect(form, contains("importantAlerts: ''"));
  });
}
