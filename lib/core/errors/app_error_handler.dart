import 'dart:async';

import '../logging/app_logger.dart';
import 'app_exception.dart';

class AppErrorHandler {
  AppErrorHandler._();

  static Future<void> record(
    Object error,
    StackTrace stackTrace, {
    String source = 'Unhandled',
    String? context,
  }) {
    return AppLogger.error(
      error,
      stackTrace,
      source: source,
      context: context,
    );
  }

  static void recordUnawaited(
    Object error,
    StackTrace stackTrace, {
    String source = 'Unhandled',
    String? context,
  }) {
    unawaited(record(error, stackTrace, source: source, context: context));
  }

  static String messageFor(Object error) {
    if (error is AppException) {
      if (error.traceId != null && error.traceId!.isNotEmpty) {
        return '${error.userMessage}\nReference: ${error.traceId}';
      }
      return error.userMessage;
    }

    return 'Something went wrong. Please try again.';
  }
}
