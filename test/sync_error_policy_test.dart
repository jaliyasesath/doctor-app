import 'package:doctor_app/core/errors/app_exception.dart';
import 'package:doctor_app/features/sync/services/sync_error_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncErrorPolicy', () {
    test('network failures are retryable', () {
      const error = AppException(
        message: 'Network unavailable',
        userMessage: 'Cannot connect to the server.',
        code: 'NETWORK_UNAVAILABLE',
        kind: AppErrorKind.network,
      );

      expect(SyncErrorPolicy.shouldRetry(error), isTrue);
    });

    test('expired session requires login', () {
      const error = AppException(
        message: 'Session expired',
        userMessage: 'Please log in again.',
        code: 'ACCESS_TOKEN_INVALID',
        kind: AppErrorKind.authentication,
        statusCode: 401,
      );

      expect(SyncErrorPolicy.requiresLogin(error), isTrue);
      expect(SyncErrorPolicy.shouldRetry(error), isFalse);
    });

    test('conflicts are not retryable', () {
      const error = AppException(
        message: 'Conflict',
        userMessage: 'The medicine already exists.',
        code: 'DUPLICATE_VALUE',
        kind: AppErrorKind.conflict,
        statusCode: 409,
      );

      expect(SyncErrorPolicy.shouldRetry(error), isFalse);
    });

    test('safe message preserves trace reference', () {
      const error = AppException(
        message: 'Internal SQL details',
        userMessage: 'The server encountered a problem.',
        code: 'INTERNAL_SERVER_ERROR',
        kind: AppErrorKind.server,
        statusCode: 500,
        traceId: 'trace-b3b',
      );

      final message = SyncErrorPolicy.message('Medicine sync', error);

      expect(message, contains('server encountered a problem'));
      expect(message, contains('trace-b3b'));
      expect(message, isNot(contains('SQL')));
    });

    test('unknown exceptions do not expose raw details', () {
      final message = SyncErrorPolicy.message(
        'Medicine sync',
        Exception('database password=secret'),
      );

      expect(message, contains('could not be completed'));
      expect(message, isNot(contains('secret')));
    });
  });
}
