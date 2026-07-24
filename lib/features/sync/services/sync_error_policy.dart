import '../../../core/errors/app_exception.dart';

class SyncErrorPolicy {
  SyncErrorPolicy._();

  static bool shouldRetry(Object error) {
    return error is AppException && error.isRetryable;
  }

  static bool requiresLogin(Object error) {
    return error is AppException && error.requiresLogin;
  }

  static String message(String operation, Object error) {
    if (error is AppException) {
      final reference = error.traceId == null || error.traceId!.isEmpty
          ? ''
          : ' Reference: ${error.traceId}.';
      return '$operation: ${error.userMessage}$reference';
    }

    return '$operation could not be completed. Please try again.';
  }
}
