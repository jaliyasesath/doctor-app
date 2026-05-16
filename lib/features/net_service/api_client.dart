import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_storage.dart';

class ApiClient {
  Uri _buildUri(String path) {
    final baseUrl = ApiConfig.baseUrl;

    if (baseUrl.trim().isEmpty) {
      throw Exception('API base URL is empty. App is in offline mode.');
    }

    return Uri.parse('$baseUrl$path');
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
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

  Future<dynamic> get(String path, {bool auth = true}) async {
    final url = _buildUri(path);

    final response = await http
        .get(
          url,
          headers: await _headers(auth: auth),
        )
        .timeout(const Duration(seconds: 20));

    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final url = _buildUri(path);

    final response = await http
        .post(
          url,
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    return _handleResponse(response);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final url = _buildUri(path);

    final response = await http
        .put(
          url,
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    bool auth = true,
  }) async {
    final url = _buildUri(path);

    final response = await http
        .delete(
          url,
          headers: await _headers(auth: auth),
        )
        .timeout(const Duration(seconds: 20));

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.isEmpty) return null;
      return jsonDecode(body);
    }

    String message = body;

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    throw Exception('API Error ${response.statusCode}: $message');
  }
}