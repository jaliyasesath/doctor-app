import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/client/pp_care_opening_hours.dart';
import 'package:doctor_app/client/pp_client_theme.dart';
import 'package:doctor_app/features/centres/centre_hours_screen.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('shared centre schedule remains usable at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final centre = <String, dynamic>{
        'id': 1,
        'name': 'Community Medical Centre',
        'timeZoneId': 'Asia/Colombo',
        'version': 1,
        'canEdit': false,
        'schedule': null
      };
      await tester
          .pumpWidget(MaterialApp(home: CentreHoursScreen(centre: centre)));
      await tester.pump();
      expect(find.text('Community Medical Centre'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.textContaining('Only the lead doctor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final dark in [false, true]) {
    testWidgets(
        'opening badge expresses centre status in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: PPClientTheme.build(dark ? Brightness.dark : Brightness.light),
          home: Scaffold(
              body: PPCareOpeningBadge(opening: const {
            'state': 'closed',
            'evaluatedAtUtc': '2026-10-19T03:00:00Z',
            'nextChangeUtc': null
          }, onRefresh: () {}))));
      expect(find.text('Centre closed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
