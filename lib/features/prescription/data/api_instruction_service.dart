import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiInstructionService {
  static const String baseUrl = 'http://192.168.8.159:5219/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> createInstruction({
    required int doctorId,
    required String instructionText,
  }) async {
    try {
      final token = await _getToken();

      final response = await http
          .post(
            Uri.parse('$baseUrl/CustomInstructions'),
            headers: _headers(token ?? ''),
            body: jsonEncode({
              'doctorId': doctorId,
              'instructionText': instructionText,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        return {
          'success': true,
          'serverId': data['id'] ?? data['Id'] ?? data['serverId'],
        };
      }

      return {
        'success': false,
        'error':
            'Instruction create failed: ${response.statusCode} ${response.body}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<List<dynamic>> getInstructions() async {
    try {
      final token = await _getToken();

      final response = await http
          .get(
            Uri.parse('$baseUrl/CustomInstructions'),
            headers: _headers(token ?? ''),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }

      return [];
    } catch (e) {
      print('Get instructions error: $e');
      return [];
    }
  }
}