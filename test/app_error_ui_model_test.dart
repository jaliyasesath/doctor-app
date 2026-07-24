import 'package:doctor_app/core/errors/app_exception.dart';
import 'package:doctor_app/core/widgets/app_error_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppErrorUiModel', () {
    test('network error offers retry without raw details', () {
      const error = AppException(
        message: 'SocketException at 10.0.0.1',
        userMessage: 'Cannot connect to the server.',
        code: 'NETWORK_UNAVAILABLE',
        kind: AppErrorKind.network,
      );

      final model = AppErrorUiModel.fromError(error);

      expect(model.message, 'Cannot connect to the server.');
      expect(model.message, isNot(contains('10.0.0.1')));
      expect(model.isRetryable, isTrue);
      expect(model.requiresLogin, isFalse);
    });

    test('expired session requests login', () {
      const error = AppException(
        message: 'JWT expired',
        userMessage: 'Your login session has expired.',
        code: 'ACCESS_TOKEN_INVALID',
        kind: AppErrorKind.authentication,
        statusCode: 401,
      );

      final model = AppErrorUiModel.fromError(error);

      expect(model.requiresLogin, isTrue);
      expect(model.isRetryable, isFalse);
    });

    test('trace reference is displayed safely', () {
      const error = AppException(
        message: 'SQL internal error',
        userMessage: 'The server encountered a problem.',
        code: 'INTERNAL_SERVER_ERROR',
        kind: AppErrorKind.server,
        statusCode: 500,
        traceId: 'trace-b4',
      );

      final model = AppErrorUiModel.fromError(error);

      expect(model.message, contains('trace-b4'));
      expect(model.message, isNot(contains('SQL')));
    });

    test('unknown error gets a generic retryable message', () {
      final model = AppErrorUiModel.fromError(
        Exception('password=secret'),
      );

      expect(model.message, 'Something went wrong. Please try again.');
      expect(model.message, isNot(contains('secret')));
      expect(model.isRetryable, isTrue);
    });
  });
}
