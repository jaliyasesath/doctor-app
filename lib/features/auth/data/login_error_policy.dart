import '../../../core/errors/app_exception.dart';

class LoginErrorPolicy {
  LoginErrorPolicy._();

  static bool canAttemptOffline(AppException error) {
    return error.canUseOfflineFallback;
  }

  static Map<String, dynamic> failureResult(AppException error) {
    return {
      'success': false,
      'message': error.userMessage,
      'code': error.code,
      if (error.statusCode != null) 'statusCode': error.statusCode,
      if (error.traceId != null && error.traceId!.isNotEmpty)
        'traceId': error.traceId,
    };
  }
}
