import 'package:doctor_app/core/errors/api_error_classifier.dart';
import 'package:doctor_app/core/errors/app_exception.dart';
import 'package:doctor_app/core/errors/offline_fallback_policy.dart';
import 'package:doctor_app/core/widgets/app_error_ui.dart';
import 'package:doctor_app/features/auth/data/login_error_policy.dart';
import 'package:doctor_app/features/sync/services/sync_error_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Error handling contract', () {
    test('invalid credentials never use offline fallback', () {
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
      expect(LoginErrorPolicy.canAttemptOffline(error), isFalse);
      expect(OfflineFallbackPolicy.isAllowed(error), isFalse);
      expect(AppErrorUiModel.fromError(error).requiresLogin, isTrue);
    });

    test('network failure is retryable and offline eligible', () {
      final error = ApiErrorClassifier.network(
        operation: 'GET /Patients',
      );
      final ui = AppErrorUiModel.fromError(error);

      expect(error.canUseOfflineFallback, isTrue);
      expect(OfflineFallbackPolicy.isAllowed(error), isTrue);
      expect(SyncErrorPolicy.shouldRetry(error), isTrue);
      expect(ui.isRetryable, isTrue);
      expect(ui.message, isNot(contains('GET /Patients')));
    });

    test('rate limiting retries but never creates offline data', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 429,
        responseBody: '{"code":"RATE_LIMIT_EXCEEDED"}',
        headers: const {'Retry-After': '30'},
      );

      expect(error.isRateLimited, isTrue);
      expect(error.retryAfter, const Duration(seconds: 30));
      expect(error.isRetryable, isTrue);
      expect(OfflineFallbackPolicy.isAllowed(error), isFalse);
    });

    test('validation failure is not retryable or offline eligible', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 400,
        responseBody: '''
        {
          "code": "VALIDATION_FAILED",
          "errors": {
            "PatientName": ["Patient name is required."]
          }
        }
        ''',
      );

      expect(error.isValidation, isTrue);
      expect(error.validationErrors['PatientName'], isNotEmpty);
      expect(error.isRetryable, isFalse);
      expect(OfflineFallbackPolicy.isAllowed(error), isFalse);
    });

    test('server failure hides internals but keeps trace reference', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 500,
        responseBody: '<html>SQL password=secret</html>',
        headers: const {'X-Trace-Id': 'trace-final-500'},
      );
      final ui = AppErrorUiModel.fromError(error);
      final syncMessage = SyncErrorPolicy.message('Patient sync', error);

      expect(error.isServerError, isTrue);
      expect(OfflineFallbackPolicy.isAllowed(error), isFalse);
      expect(ui.message, contains('trace-final-500'));
      expect(ui.message, isNot(contains('secret')));
      expect(syncMessage, isNot(contains('secret')));
    });

    test('API timeout is retryable and offline eligible', () {
      final error = ApiErrorClassifier.fromHttpResponse(
        statusCode: 503,
        responseBody: '{"code":"REQUEST_TIMEOUT"}',
      );

      expect(error.isTimeout, isTrue);
      expect(error.isRetryable, isTrue);
      expect(OfflineFallbackPolicy.isAllowed(error), isTrue);
    });
  });
}
