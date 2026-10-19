import 'package:flutter/services.dart';
import 'package:doctor_app/client/pp_client_queue_screens.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_app/client/pp_client_config.dart';
import 'package:doctor_app/client/pp_client_session.dart';
import 'package:doctor_app/client/pp_client_theme.dart';
import 'package:doctor_app/client/pp_client_health_feed.dart';
import 'package:doctor_app/core/health_posts/health_post_labels.dart';

class _FeedSession extends PPClientSession {
  _FeedSession() {
    profile = {'patientAccountId': 7, 'profileComplete': true};
  }
  @override
  Future<Map<String, dynamic>> findDoctors(
          {double? latitude,
          double? longitude,
          String search = '',
          int page = 1}) async =>
      {'items': [], 'hasMore': false};
  @override
  Future<Map<String, dynamic>> doctorDetails(int id) async => {
        'doctor': {'doctorId': id, 'doctorName': 'Long Doctor Name Perera'},
        'waitingCount': 0,
        'nowServing': 0
      };
  @override
  Future<Map<String, dynamic>> bookDoctor(int id, String requestId) async =>
      {'queueNo': 5, 'status': 'Active'};

  String? requestedMode, requestedTopic;
  int followed = 0;
  bool official = false;
  @override
  bool get signedIn => true;
  @override
  Future<Map<String, dynamic>> healthTopics() async => {
        'topics': [
          {
            'id': 'general',
            'en': 'General Health',
            'si': 'සාමාන්‍ය සෞඛ්‍යය',
            'ta': 'பொது சுகாதாரம்',
          },
          {
            'id': 'nutrition',
            'en': 'Nutrition',
            'si': 'පෝෂණය',
            'ta': 'ஊட்டச்சத்து',
          },
        ],
      };
  @override
  Future<Map<String, dynamic>> healthFeed({
    String mode = 'latest',
    String? topic,
    String? language,
    String? cursor,
  }) async {
    requestedMode = mode;
    requestedTopic = topic;
    return {
      'hasMore': false,
      'items': mode == 'following'
          ? <Map<String, dynamic>>[]
          : [
              {
                'id': 1,
                'doctorId': official ? null : 9,
                'isOfficial': official,
                'doctorName': 'Long Doctor Name Perera',
                'specialization': 'General Practitioner',
                'title': 'A helpful health update',
                'content': 'General information for the community.',
                'sourceUrl': '',
                'hasPhoto': false,
                'isFollowing': false,
                'isSaved': false,
                'isHelpful': false,
                'helpfulCount': 0,
                'version': 1,
                'publishedAt': '2026-10-16T07:00:00Z',
              },
            ],
    };
  }

  @override
  Future<void> healthFollow(int doctorId, bool value) async {
    followed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('official author opens team details without doctor navigation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = _FeedSession()..official = true;
    var openedDoctor = false;
    await tester.pumpWidget(MaterialApp(
        theme: PPClientTheme.build(Brightness.light),
        home: PPClientHealthFeed(
            session: session,
            onDoctor: (_) async {
              openedDoctor = true;
            },
              onMyQueue: () {},
            onProfile: () {})));
    await tester.pumpAndSettle();
    expect(find.text('PP Health Team'), findsOneWidget);
    await tester.tap(find.text('PP Health Team'));
    await tester.pumpAndSettle();
    expect(openedDoctor, isFalse);
    expect(find.textContaining('Official health tips'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('module labels support English Sinhala and Tamil', () {
    expect(const HealthPostLabels('en').t('feed'), 'Health Feed');
    expect(const HealthPostLabels('si').t('feed'), 'සෞඛ්‍ය ලිපි');
    expect(const HealthPostLabels('ta').t('feed'), 'சுகாதாரப் பதிவுகள்');
  });
  test('feed requests use patient credentials and encoded filters', () async {
    FlutterSecureStorage.setMockInitialValues({
      'pp_client_identity_session_v1': jsonEncode({
        'origin': PPClientConfig.origin.toString(),
        'access': 'patient-access',
        'refresh': 'patient-refresh',
        'expires': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      }),
    });
    final session = PPClientSession(
      transport: MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer patient-access');
        expect(r.followRedirects, false);
        if (r.url.path.endsWith('/profile')) {
          return http.Response(jsonEncode({'patientAccountId': 7}), 200);
        }
        expect(r.url.path, '/api/client/health-feed');
        expect(r.url.queryParameters['mode'], 'following');
        expect(r.url.queryParameters['topic'], 'nutrition');
        expect(r.url.queryParameters['language'], 'si');
        expect(r.url.queryParameters['cursor'], '123.45');
        return http.Response('{"items":[],"hasMore":false}', 200);
      }),
    );
    await session.restore();
    await session.healthFeed(
      mode: 'following',
      topic: 'nutrition',
      language: 'si',
      cursor: '123.45',
    );
    session.dispose();
  });
  test('slow feed photos do not block doctor details on the shared session',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'pp_client_identity_session_v1': jsonEncode({
        'origin': PPClientConfig.origin.toString(),
        'access': 'patient-access',
        'refresh': 'patient-refresh',
        'expires': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String()
      })
    });
    final pending = Completer<http.Response>();
    final photoStarted = Completer<void>();
    final session = PPClientSession(transport: MockClient((request) async {
      if (request.url.path.endsWith('/profile')) {
        return http.Response('{"patientAccountId":7}', 200);
      }
      if (request.url.path.endsWith('/photo')) {
        photoStarted.complete();
        return pending.future;
      }
      return http.Response('{"doctor":{"doctorId":9}}', 200);
    }));
    await session.restore();
    final photo = session.healthPhoto(1);
    await photoStarted.future;
    final details =
        await session.doctorDetails(9).timeout(const Duration(seconds: 1));
    expect(details['doctor']['doctorId'], 9);
    pending.complete(http.Response.bytes([255, 216, 255], 200,
        headers: {'content-type': 'image/jpeg'}));
    expect(await photo, [255, 216, 255]);
    session.dispose();
  });
  for (final complete in [true, false]) {
    testWidgets(
        'feed doctor booking returns to the existing ${complete ? 'queue' : 'profile'} flow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'isLocationServiceEnabled' ? false : null);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final session = _FeedSession();
      session.profile!['profileComplete'] = complete;
      addTearDown(session.dispose);
      var booked = 0, profile = 0;
      await tester.pumpWidget(MaterialApp(
          theme: PPClientTheme.build(Brightness.light),
          home: Scaffold(
              body: PPClientDoctorBrowser(
                  session: session,
                  homeMode: true,
                  onProfileRequired: () => profile++,
                  onBooked: () => booked++))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Health Feed'));
      await tester.tap(find.text('Health Feed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dr. Long Doctor Name Perera'));
      await tester.tap(find.text('Dr. Long Doctor Name Perera'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Book today’s queue'));
      await tester.tap(find.text('Book today’s queue'));
      await tester.pumpAndSettle();
      if (complete) {
        await tester.tap(find.text('Confirm booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View My Queue'));
        await tester.pumpAndSettle();
      }
      expect(booked, complete ? 1 : 0);
      expect(profile, complete ? 0 : 1);
      expect(find.text('Explore Topics'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'feed fits 320px at $brightness scale $scale and opens doctor profile',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final session = _FeedSession();
          addTearDown(session.dispose);
          int? doctor;
          await tester.pumpWidget(
            MaterialApp(
              theme: PPClientTheme.build(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: PPClientHealthFeed(
                session: session,
                onDoctor: (id) async {
                  doctor = id;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Dr. Long Doctor Name Perera'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Dr. Long Doctor Name Perera'));
          expect(doctor, 9);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('following has explicit empty state and topics reach query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = _FeedSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PPClientHealthFeed(session: session, onDoctor: (_) async {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutrition'));
    await tester.pumpAndSettle();
    expect(session.requestedTopic, 'nutrition');
    await tester.tap(find.text('Following').first);
    await tester.pumpAndSettle();
    expect(session.requestedMode, 'following');
    expect(
      find.text('Follow doctors to see their updates here.'),
      findsOneWidget,
    );
  });
}
