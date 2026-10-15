import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/client/pp_client_theme.dart';
import 'package:doctor_app/client/pp_client_queue_screens.dart';
import 'package:doctor_app/client/pp_client_session.dart';

class _PreviewSession extends PPClientSession {
  @override
  Future<Map<String, dynamic>> findDoctors({double? latitude, double? longitude,
      String search = '', int page = 1}) async => {
    'hasMore': false,
    'items': [
      {'doctorId': 1, 'medicalCenterName': 'Green Cross Medical Centre with a long name',
        'doctorName': 'Dr. N. Perera', 'specialization': 'General Practitioner',
        'distanceKm': 0.8, 'waitingCount': 10, 'nowServing': 12},
      {'doctorId': 2, 'medicalCenterName': 'City Medical Centre',
        'doctorName': 'Dr. S. Fernando', 'specialization': 'Family Physician',
        'distanceKm': 1.4, 'waitingCount': 20, 'nowServing': 6},
    ],
  };
}

void main() {
  test('device local time switches at exactly 06:00 and 18:00', () {
    for (final pair in <(DateTime, ThemeMode)>[
      (DateTime(2026, 10, 15, 5, 59, 59), ThemeMode.dark),
      (DateTime(2026, 10, 15, 6), ThemeMode.light),
      (DateTime(2026, 10, 15, 17, 59, 59), ThemeMode.light),
      (DateTime(2026, 10, 15, 18), ThemeMode.dark),
      (DateTime(2026, 10, 16), ThemeMode.dark),
    ]) {
      expect(PPClientThemeClock.modeAt(pair.$1), pair.$2);
    }
  });

  testWidgets('theme changes while open and rechecks after resume', (tester) async {
    var now = DateTime(2026, 10, 15, 17, 59, 59);
    final clock = PPClientThemeClock(now: () => now);
    expect(clock.mode, ThemeMode.light);
    now = DateTime(2026, 10, 15, 18);
    await tester.pump(const Duration(seconds: 1));
    expect(clock.mode, ThemeMode.dark);
    clock.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = DateTime(2026, 10, 16, 6);
    clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(clock.mode, ThemeMode.light);
    clock.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home fits 320px at $brightness and text scale $scale', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const channel = MethodChannel('flutter.baseflow.com/geolocator');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
            (call) async => call.method == 'isLocationServiceEnabled' ? false : null);
        addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
        final session = _PreviewSession();
        addTearDown(session.dispose);
        await tester.pumpWidget(MaterialApp(
          theme: PPClientTheme.build(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: PPClientDoctorBrowser(
            session: session, homeMode: true,
            onProfileRequired: () {}, onBooked: () {},
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Your location'), findsOneWidget);
        expect(find.text('Change'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Health Services'), 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.text('Health Services'), findsOneWidget);
        expect(find.text('Find Doctor'), findsOneWidget);
        expect(find.text('My Queue'), findsOneWidget);
        expect(find.text('Health Records'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('City Medical Centre'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.text('20 patients'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());

      });
    }
  }
}
