import 'package:doctor_app/core/errors/app_exception.dart';
import 'package:doctor_app/features/auth/data/login_error_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginErrorPolicy', () {
    test('allows offline login after a network failure', () {
      const error = AppException(
        message: 'Network unavailable',
        userMessage: 'Cannot connect to the server.',
        code: 'NETWORK_UNAVAILABLE',
        kind: AppErrorKind.network,
      );

      expect(LoginErrorPolicy.canAttemptOffline(error), isTrue);
    });

    test('allows offline login after a timeout', () {
      const error = AppException(
        message: 'Request timed out',
        userMessage: 'The server is taking too long to respond.',
        code: 'REQUEST_TIMEOUT',
        kind: AppErrorKind.timeout,
      );

      expect(LoginErrorPolicy.canAttemptOffline(error), isTrue);
    });

    test('blocks offline fallback for invalid credentials', () {
      const error = AppException(
        message: 'Invalid credentials',
        userMessage: 'The email or password is incorrect.',
        code: 'INVALID_CREDENTIALS',
        kind: AppErrorKind.authentication,
        statusCode: 401,
      );

      expect(LoginErrorPolicy.canAttemptOffline(error), isFalse);
    });

    test('blocks offline fallback for server failures', () {
      const error = AppException(
        message: 'Server failure',
        userMessage: 'The server encountered a problem.',
        code: 'INTERNAL_SERVER_ERROR',
        kind: AppErrorKind.server,
        statusCode: 500,
      );

      expect(LoginErrorPolicy.canAttemptOffline(error), isFalse);
    });

    test('preserves safe API details in the login failure result', () {
      const error = AppException(
        message: 'Forbidden',
        userMessage: 'You do not have permission.',
        code: 'ACCESS_FORBIDDEN',
        kind: AppErrorKind.authorization,
        statusCode: 403,
        traceId: 'trace-b2',
      );

      final result = LoginErrorPolicy.failureResult(error);

      expect(result['success'], isFalse);
      expect(result['message'], 'You do not have permission.');
      expect(result['code'], 'ACCESS_FORBIDDEN');
      expect(result['statusCode'], 403);
      expect(result['traceId'], 'trace-b2');
    });
  });
}
