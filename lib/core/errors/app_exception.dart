enum AppErrorKind {
  network,
  timeout,
  authentication,
  authorization,
  validation,
  notFound,
  conflict,
  rateLimited,
  server,
  cancelled,
  invalidResponse,
  configuration,
  unknown,
}

class AppException implements Exception {
  const AppException({
    required this.message,
    required this.userMessage,
    this.code = 'APP_ERROR',
    this.kind = AppErrorKind.unknown,
    this.statusCode,
    this.traceId,
    this.validationErrors = const {},
    this.retryAfter,
    this.cause,
  });

  final String message;
  final String userMessage;
  final String code;
  final AppErrorKind kind;
  final int? statusCode;
  final String? traceId;
  final Map<String, List<String>> validationErrors;
  final Duration? retryAfter;
  final Object? cause;

  bool get isNetworkError => kind == AppErrorKind.network;
  bool get isTimeout => kind == AppErrorKind.timeout;
  bool get isUnauthorized => kind == AppErrorKind.authentication;
  bool get isForbidden => kind == AppErrorKind.authorization;
  bool get isValidation => kind == AppErrorKind.validation;
  bool get isNotFound => kind == AppErrorKind.notFound;
  bool get isConflict => kind == AppErrorKind.conflict;
  bool get isRateLimited => kind == AppErrorKind.rateLimited;
  bool get isServerError => kind == AppErrorKind.server;
  bool get isCancelled => kind == AppErrorKind.cancelled;

  bool get canUseOfflineFallback =>
      isNetworkError || isTimeout;

  bool get isRetryable =>
      isNetworkError ||
      isTimeout ||
      isRateLimited ||
      statusCode == 502 ||
      statusCode == 503;

  bool get requiresLogin => isUnauthorized;

  @override
  String toString() {
    final reference = traceId == null || traceId!.isEmpty
        ? ''
        : ' (Reference: $traceId)';
    return '$userMessage$reference';
  }
}
