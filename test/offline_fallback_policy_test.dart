import 'dart:async';

import 'package:doctor_app/core/errors/app_exception.dart';
import 'package:doctor_app/core/errors/offline_fallback_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineFallbackPolicy', () {
    test('allows classified network errors', () {
      const error = AppException(
        message: 'Network unavailable',
        userMessage: 'Cannot connect to the server.',
        code: 'NETWORK_UNAVAILABLE',
        kind: AppErrorKind.network,
      );

      expect(OfflineFallbackPolicy.isAllowed(error), isTrue);
    });

    test('allows timeout errors', () {
      expect(
        OfflineFallbackPolicy.isAllowed(TimeoutException('timeout')),
        isTrue,
      );
    });

    test('allows explicit offline mode', () {
      const error = AppException(
        message: 'Offline mode',
        userMessage: 'The app is offline.',
        code: 'OFFLINE_MODE',
        kind: AppErrorKind.configuration,
      );

      expect(OfflineFallbackPolicy.isAllowed(error), isTrue);
    });

    test('blocks authentication errors', () {
      const error = AppException(
        message: 'Unauthorized',
        userMessage: 'Please log in again.',
        code: 'ACCESS_TOKEN_INVALID',
        kind: AppErrorKind.authentication,
        statusCode: 401,
      );

      expect(OfflineFallbackPolicy.isAllowed(error), isFalse);
    });

    test('blocks conflict errors', () {
      const error = AppException(
        message: 'Conflict',
        userMessage: 'The record already exists.',
        code: 'DUPLICATE_VALUE',
        kind: AppErrorKind.conflict,
        statusCode: 409,
      );

      expect(OfflineFallbackPolicy.isAllowed(error), isFalse);
    });

    test('blocks rate-limit and server errors', () {
      const rateLimit = AppException(
        message: 'Rate limited',
        userMessage: 'Please wait.',
        code: 'RATE_LIMIT_EXCEEDED',
        kind: AppErrorKind.rateLimited,
        statusCode: 429,
      );
      const server = AppException(
        message: 'Server error',
        userMessage: 'Server problem.',
        code: 'INTERNAL_SERVER_ERROR',
        kind: AppErrorKind.server,
        statusCode: 500,
      );

      expect(OfflineFallbackPolicy.isAllowed(rateLimit), isFalse);
      expect(OfflineFallbackPolicy.isAllowed(server), isFalse);
    });
  });
}
