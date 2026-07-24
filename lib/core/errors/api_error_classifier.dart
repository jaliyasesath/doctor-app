import 'dart:convert';

import 'app_exception.dart';

class ApiErrorClassifier {
  ApiErrorClassifier._();

  static AppException fromHttpResponse({
    required int statusCode,
    required String responseBody,
    Map<String, String> headers = const {},
  }) {
    final body = _decodeObject(responseBody);
    final detail = _cleanText(body?['detail']);
    final message = _cleanText(body?['message']);
    final title = _cleanText(body?['title']);
    final serverCode = _cleanText(body?['code']);
    final code = serverCode.isEmpty ? 'HTTP_$statusCode' : serverCode;
    final traceId = _firstNotEmpty([
      _cleanText(body?['traceId']),
      _header(headers, 'x-trace-id'),
      _header(headers, 'x-correlation-id'),
    ]);
    final validationErrors = _readValidationErrors(body?['errors']);
    final retryAfter = _readRetryAfter(headers);
    final serverMessage = _firstNotEmpty([detail, message, title]);
    final kind = _kindFor(statusCode, code);

    return AppException(
      message: _internalMessage(
        statusCode,
        code,
        serverMessage,
        responseBody,
      ),
      userMessage: _userMessage(
        code: code,
        kind: kind,
        serverMessage: serverMessage,
        retryAfter: retryAfter,
      ),
      code: code,
      kind: kind,
      statusCode: statusCode,
      traceId: traceId.isEmpty ? null : traceId,
      validationErrors: validationErrors,
      retryAfter: retryAfter,
    );
  }

  static AppException network({
    required String operation,
    Object? cause,
  }) {
    return AppException(
      message: '$operation failed because the network is unavailable.',
      userMessage:
          'Cannot connect to the server. Check your internet connection.',
      code: 'NETWORK_UNAVAILABLE',
      kind: AppErrorKind.network,
      cause: cause,
    );
  }

  static AppException timeout({
    required String operation,
    Object? cause,
  }) {
    return AppException(
      message: '$operation timed out.',
      userMessage:
          'The server is taking too long to respond. Please try again.',
      code: 'REQUEST_TIMEOUT',
      kind: AppErrorKind.timeout,
      cause: cause,
    );
  }

  static AppException invalidResponse({
    required String operation,
    Object? cause,
  }) {
    return AppException(
      message: '$operation returned an invalid response.',
      userMessage:
          'The server returned an invalid response. Please try again.',
      code: 'INVALID_RESPONSE',
      kind: AppErrorKind.invalidResponse,
      cause: cause,
    );
  }

  static AppException unexpected({
    required String operation,
    Object? cause,
  }) {
    return AppException(
      message: '$operation failed unexpectedly.',
      userMessage: 'Something went wrong while contacting the server.',
      code: 'UNEXPECTED_API_ERROR',
      kind: AppErrorKind.unknown,
      cause: cause,
    );
  }

  static Map<String, dynamic>? _decodeObject(String value) {
    if (value.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static AppErrorKind _kindFor(int statusCode, String code) {
    if (code == 'REQUEST_TIMEOUT' ||
        statusCode == 408 ||
        statusCode == 504) {
      return AppErrorKind.timeout;
    }

    switch (statusCode) {
      case 400:
      case 422:
        return AppErrorKind.validation;
      case 401:
        return AppErrorKind.authentication;
      case 403:
        return AppErrorKind.authorization;
      case 404:
        return AppErrorKind.notFound;
      case 409:
        return AppErrorKind.conflict;
      case 429:
        return AppErrorKind.rateLimited;
      default:
        return statusCode >= 500
            ? AppErrorKind.server
            : AppErrorKind.unknown;
    }
  }

  static String _userMessage({
    required String code,
    required AppErrorKind kind,
    required String serverMessage,
    required Duration? retryAfter,
  }) {
    if (code == 'INVALID_CREDENTIALS' ||
        code == 'ADMIN_INVALID_CREDENTIALS') {
      return 'The email or password is incorrect.';
    }

    if (code == 'REFRESH_TOKEN_EXPIRED' ||
        code == 'REFRESH_TOKEN_REUSED' ||
        code == 'INVALID_REFRESH_TOKEN' ||
        code == 'ACCESS_TOKEN_INVALID') {
      return 'Your login session has expired. Please log in again.';
    }

    switch (kind) {
      case AppErrorKind.validation:
        return serverMessage.isEmpty
            ? 'Please check the entered information.'
            : serverMessage;
      case AppErrorKind.authentication:
        return 'Your login session has expired. Please log in again.';
      case AppErrorKind.authorization:
        return serverMessage.isEmpty
            ? 'You do not have permission to perform this action.'
            : serverMessage;
      case AppErrorKind.notFound:
        return serverMessage.isEmpty
            ? 'The requested record was not found.'
            : serverMessage;
      case AppErrorKind.conflict:
        return serverMessage.isEmpty
            ? 'This record conflicts with another saved record.'
            : serverMessage;
      case AppErrorKind.rateLimited:
        final seconds = retryAfter?.inSeconds;
        return seconds == null
            ? 'Too many requests. Please wait and try again.'
            : 'Too many requests. Please try again in $seconds seconds.';
      case AppErrorKind.timeout:
        return 'The server is taking too long to respond. Please try again.';
      case AppErrorKind.server:
        return 'The server encountered a problem. Please try again.';
      default:
        return serverMessage.isEmpty
            ? 'The request could not be completed.'
            : serverMessage;
    }
  }

  static Map<String, List<String>> _readValidationErrors(dynamic value) {
    if (value is! Map) return const {};

    final result = <String, List<String>>{};
    value.forEach((key, messages) {
      if (key is! String) return;

      if (messages is List) {
        final cleanMessages = messages
            .map(_cleanText)
            .where((message) => message.isNotEmpty)
            .toList(growable: false);
        if (cleanMessages.isNotEmpty) result[key] = cleanMessages;
      } else {
        final cleanMessage = _cleanText(messages);
        if (cleanMessage.isNotEmpty) result[key] = [cleanMessage];
      }
    });
    return Map.unmodifiable(result);
  }

  static Duration? _readRetryAfter(Map<String, String> headers) {
    final rawValue = _header(headers, 'retry-after');
    final seconds = int.tryParse(rawValue);
    return seconds == null || seconds < 0
        ? null
        : Duration(seconds: seconds);
  }

  static String _header(
    Map<String, String> headers,
    String requestedName,
  ) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == requestedName.toLowerCase()) {
        return entry.value.trim();
      }
    }
    return '';
  }

  static String _cleanText(dynamic value) {
    if (value == null) return '';
    final text = value.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return text.length <= 500 ? text : text.substring(0, 500);
  }

  static String _firstNotEmpty(List<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _internalMessage(
    int statusCode,
    String code,
    String serverMessage,
    String rawBody,
  ) {
    final description = serverMessage.isNotEmpty
        ? serverMessage
        : rawBody.trim().isEmpty
            ? 'No response body.'
            : 'Non-JSON response body omitted.';
    return 'HTTP $statusCode [$code]: $description';
  }
}
