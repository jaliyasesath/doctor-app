import 'package:doctor_app/features/queue/services/queue_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Queue realtime hub URL', () {
    test('uses the VPS IP API base path', () {
      expect(
        QueueRealtimeService.hubUrlFor(
          'http://169.58.40.160/api',
        ),
        'http://169.58.40.160/api/hubs/queue',
      );
    });

    test('uses the local Wi-Fi API base path', () {
      expect(
        QueueRealtimeService.hubUrlFor(
          'http://192.168.8.91:5219/api/',
        ),
        'http://192.168.8.91:5219/api/hubs/queue',
      );
    });

    test('rejects an empty API URL', () {
      expect(
        QueueRealtimeService.hubUrlFor('  '),
        isNull,
      );
    });
  });
}
