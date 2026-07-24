import 'package:doctor_app/core/errors/api_error_classifier.dart';
import 'package:doctor_app/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiErrorClassifier', () {
    test('parses validation ProblemDetails', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 400,
        responseBody: '''
        {
          "title": "Validation failed",
          "detail": "One or more request values are invalid.",
          "code": "VALIDATION_FAILED",
          "traceId": "trace-400",
          "errors": {
            "Email": ["Email is required."]
          }
        }
        ''',
      );

      expect(error.kind, AppErrorKind.validation);
      expect(error.code, 'VALIDATION_FAILED');
      expect(error.traceId, 'trace-400');
      expect(error.validationErrors['Email'], ['Email is required.']);
      expect(error.canUseOfflineFallback, isFalse);
    });

    test('distinguishes invalid login from expired session', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 401,
        responseBody: '''
        {
          "code": "INVALID_CREDENTIALS",
          "detail": "The email or password is incorrect."
        }
        ''',
      );

      expect(error.kind, AppErrorKind.authentication);
      expect(error.userMessage, 'The email or password is incorrect.');
      expect(error.requiresLogin, isTrue);
      expect(error.canUseOfflineFallback, isFalse);
    });

    test('classifies authorization failure', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 403,
        responseBody: '{"code":"ACCESS_FORBIDDEN"}',
      );

      expect(error.kind, AppErrorKind.authorization);
      expect(error.isForbidden, isTrue);
      expect(error.canUseOfflineFallback, isFalse);
    });

    test('classifies conflict without offline fallback', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 409,
        responseBody: '''
        {
          "code": "DUPLICATE_VALUE",
          "detail": "The record already exists."
        }
        ''',
      );

      expect(error.kind, AppErrorKind.conflict);
      expect(error.isConflict, isTrue);
      expect(error.canUseOfflineFallback, isFalse);
    });

    test('parses Retry-After for rate limiting', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 429,
        responseBody: '{"code":"RATE_LIMIT_EXCEEDED"}',
        headers: const {'retry-after': '15'},
      );

      expect(error.kind, AppErrorKind.rateLimited);
      expect(error.retryAfter, const Duration(seconds: 15));
      expect(error.isRetryable, isTrue);
      expect(error.canUseOfflineFallback, isFalse);
    });

    test('classifies API timeout as offline-fallback eligible', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 503,
        responseBody: '{"code":"REQUEST_TIMEOUT"}',
      );

      expect(error.kind, AppErrorKind.timeout);
      expect(error.isTimeout, isTrue);
      expect(error.canUseOfflineFallback, isTrue);
    });

    test('does not treat server error as offline', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 500,
        responseBody: '<html>server failure</html>',
        headers: const {'X-Trace-Id': 'trace-500'},
      );

      expect(error.kind, AppErrorKind.server);
      expect(error.traceId, 'trace-500');
      expect(error.canUseOfflineFallback, isFalse);
      expect(error.userMessage, contains('server'));
    });
  });
}
