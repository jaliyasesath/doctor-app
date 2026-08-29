import 'package:doctor_app/features/queue/services/queue_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Queue realtime hub URL', () {
    test('uses the production HTTPS API base path', () {
      expect(
        QueueRealtimeService.hubUrlFor(
          'https://api.example.com/api',
        ),
        'https://api.example.com/api/hubs/queue',
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
