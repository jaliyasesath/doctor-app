import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_error_handler.dart';
import '../../core/errors/api_error_classifier.dart';
import '../../core/errors/app_exception.dart';
import 'api_config.dart';
import 'token_storage.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 20);
  static Future<bool>? _refreshOperation;

  static Future<bool> refreshSession() => _refreshAccessToken();

  Uri _buildUri(String path) {
    final baseUrl = ApiConfig.baseUrl.trim();

    if (baseUrl.isEmpty) {
      throw const AppException(
        message: 'API base URL is empty.',
        userMessage: 'The app is currently in offline mode.',
        code: 'OFFLINE_MODE',
        kind: AppErrorKind.configuration,
      );
    }

    try {
      return Uri.parse('$baseUrl$path');
    } on FormatException catch (error) {
      throw AppException(
        message: 'Invalid API URL: $baseUrl$path',
        userMessage:
            'The server address is invalid. Check connection settings.',
        code: 'INVALID_API_URL',
        kind: AppErrorKind.configuration,
        cause: error,
      );
    }
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (auth) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true}) {
    return _send(
      method: 'GET',
      path: path,
      auth: auth,
      request: (url, headers) => http.get(url, headers: headers),
    );
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _send(
      method: 'POST',
      path: path,
      auth: auth,
      request: (url, headers) => http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      auth: auth,
      request: (url, headers) => http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String path, {bool auth = true}) {
    return _send(
      method: 'DELETE',
      path: path,
      auth: auth,
      request: (url, headers) => http.delete(url, headers: headers),
    );
  }

  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, String> fields = const {},
  }) async {
    Future<http.Response> send(bool retry) async {
      final request = http.MultipartRequest('POST', _buildUri(path));
      final headers = await _headers();
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      if (retry && response.statusCode == 401 && await _refreshAccessToken()) {
        return send(false);
      }
      return response;
    }

    try {
      return _handleResponse(await send(true));
    } on TimeoutException catch (error) {
      throw ApiErrorClassifier.timeout(operation: 'POST $path', cause: error);
    } on SocketException catch (error) {
      throw ApiErrorClassifier.network(operation: 'POST $path', cause: error);
    }
  }

  Future<http.Response> download(String path) async {
    var response = await http
        .get(_buildUri(path), headers: await _headers())
        .timeout(_requestTimeout);
    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await http
          .get(_buildUri(path), headers: await _headers())
          .timeout(_requestTimeout);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _handleResponse(response);
    }
    return response;
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    required bool auth,
    required Future<http.Response> Function(
      Uri url,
      Map<String, String> headers,
    ) request,
  }) async {
    try {
      final url = _buildUri(path);
      var response = await request(
        url,
        await _headers(auth: auth),
      ).timeout(_requestTimeout);

      if (auth && response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          response = await request(
            url,
            await _headers(auth: true),
          ).timeout(_requestTimeout);
        }
      }

      return _handleResponse(response);
    } on AppException catch (error, stackTrace) {
      if (error.isServerError || error.isConflict) {
        AppErrorHandler.recordUnawaited(
          error,
          stackTrace,
          source: 'ApiClient',
          context: '$method $path',
        );
      }
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      final exception = ApiErrorClassifier.timeout(
        operation: '$method $path',
        cause: error,
      );
      AppErrorHandler.recordUnawaited(
        exception,
        stackTrace,
        source: 'ApiClient',
        context: '$method $path',
      );
      throw exception;
    } on SocketException catch (error, stackTrace) {
      final exception = ApiErrorClassifier.network(
        operation: '$method $path',
        cause: error,
      );
      AppErrorHandler.recordUnawaited(
        exception,
        stackTrace,
        source: 'ApiClient',
        context: '$method $path',
      );
      throw exception;
    } on http.ClientException catch (error, stackTrace) {
      final exception = ApiErrorClassifier.network(
        operation: '$method $path',
        cause: error,
      );
      AppErrorHandler.recordUnawaited(
        exception,
        stackTrace,
        source: 'ApiClient',
        context: '$method $path',
      );
      throw exception;
    } on FormatException catch (error, stackTrace) {
      final exception = ApiErrorClassifier.invalidResponse(
        operation: '$method $path',
        cause: error,
      );
      AppErrorHandler.recordUnawaited(
        exception,
        stackTrace,
        source: 'ApiClient',
        context: '$method $path',
      );
      throw exception;
    } catch (error, stackTrace) {
      final exception = ApiErrorClassifier.unexpected(
        operation: '$method $path',
        cause: error,
      );
      AppErrorHandler.recordUnawaited(
        exception,
        stackTrace,
        source: 'ApiClient',
        context: '$method $path',
      );
      throw exception;
    }
  }

  static Future<bool> _refreshAccessToken() async {
    final running = _refreshOperation;
    if (running != null) return running;

    final operation = _performRefresh();
    _refreshOperation = operation;

    try {
      return await operation;
    } finally {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    }
  }

  static Future<bool> _performRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final baseUrl = ApiConfig.baseUrl.trim();
    if (baseUrl.isEmpty) return false;

    try {
      final deviceId = await TokenStorage.getOrCreateDeviceId();
      final response = await http
          .post(
            Uri.parse('$baseUrl/Auth/refresh'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'refreshToken': refreshToken,
              'deviceId': deviceId,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return false;

        final accessToken = decoded['token']?.toString() ?? '';
        final replacementRefreshToken =
            decoded['refreshToken']?.toString() ?? '';

        if (accessToken.isEmpty || replacementRefreshToken.isEmpty) {
          return false;
        }

        await TokenStorage.saveTokenPair(
          accessToken: accessToken,
          refreshToken: replacementRefreshToken,
        );
        return true;
      }

      if (response.statusCode == 400 || response.statusCode == 401) {
        await TokenStorage.clearToken();
      }
      return false;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on FormatException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    }

    throw ApiErrorClassifier.fromHttpResponse(
      statusCode: response.statusCode,
      responseBody: body,
      headers: response.headers,
    );
  }
}
