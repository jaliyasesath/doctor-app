import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/features/health_posts/doctor_health_posts_screen.dart';
import 'package:doctor_app/features/health_posts/health_posts_service.dart';

class _PostsApi extends HealthPostsService {
  int creates = 0, composes = 0;
  Map<String, dynamic>? last;
  @override
  Future<Map<String, dynamic>> topics() async => {
        'topics': [
          {
            'id': 'general',
            'en': 'General Health',
            'si': 'සාමාන්‍ය සෞඛ්‍යය',
            'ta': 'பொது சுகாதாரம்'
          }
        ]
      };
  @override
  Future<Map<String, dynamic>> create(
      Map<String, dynamic> body, String requestId) async {
    creates++;
    return {
      ...body,
      'id': 42,
      'version': 1,
      'hasPhoto': false,
      'isPublished': false
    };
  }

  @override
  Future<Map<String, dynamic>> compose(int id, Map<String, dynamic> body,
      {String? photoPath}) async {
    composes++;
    last = body;
    return {
      ...body,
      'id': id,
      'version': 2,
      'hasPhoto': false,
      'isPublished': body['publish']
    };
  }
}

void main() {
  for (final size in [const Size(320, 900), const Size(1440, 1000)]) {
    testWidgets('editor fits $size and publishes through one atomic compose',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PostsApi();
      bool? saved;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      key: const Key('open'),
                      onPressed: () async {
                        saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    DoctorHealthPostEditor(service: api)));
                      },
                      child: const Text('Open editor'))))));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField).at(0), 'A useful post');
      await tester.ensureVisible(find.byType(TextFormField).at(1));
      await tester.enterText(
          find.byType(TextFormField).at(1), 'General health information.');
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(api.creates, 1);
      expect(api.composes, 1);
      expect(api.last!['publish'], true);
      expect(api.last!['expectedVersion'], 1);
      expect(saved, true);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unsaved post requires explicit discard before leaving',
      (tester) async {
    final api = _PostsApi();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DoctorHealthPostEditor(service: api))),
                    child: const Text('Open editor'))))));
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved title');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Create Post'), findsOneWidget);
    expect(api.creates, 0);
  });
}
