import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../net_service/api_config.dart';

class ApiMedicineService {
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

  Uri _uri(String path) {
    final baseUrl = ApiConfig.baseUrl;

    if (baseUrl.trim().isEmpty) {
      throw Exception('API base URL is empty. App is in offline mode.');
    }

    return Uri.parse('$baseUrl$path');
  }

  Map<String, dynamic> _medicineBody({
  int? doctorId,
  int? serverId,
  required String name,
  String? generic,
  String? brand,
  String? group,
  String? doseForm,
  String? strength,
  String? customDosage,
  String? customFrequency,
  String? customDuration,
  String? customInstructions,
  double sellingPrice = 0,
  double costPrice = 0,
  bool isFavorite = false,
}) {
  return {
    'id': serverId,
    'doctorId': doctorId,
    'medicineName': name,
    'genericName': generic ?? '',
    'brandName': brand ?? '',
    'drugGroup': group ?? '',
    'medicineType': doseForm ?? '',
    'defaultDosage': strength ?? '',
    'defaultFrequency': '',
    'defaultDuration': '',
    'instructions': '',
    'customDosage': customDosage ?? '',
    'customFrequency': customFrequency ?? '',
    'customDuration': customDuration ?? '',
    'customInstructions': customInstructions ?? '',
    'sellingPrice': sellingPrice,
    'costPrice': costPrice,
    'isFavorite': isFavorite,
    'isGlobal': false,
    'assignedDoctorIds': [],
  };
}

  Future<Map<String, dynamic>> createMedicine({
  required int doctorId,
  required String name,
  String? generic,
  String? brand,
  String? group,
  String? doseForm,
  String? strength,
  String? customDosage,
  String? customFrequency,
  String? customDuration,
  String? customInstructions,
  double sellingPrice = 0,
  double costPrice = 0,
  bool isFavorite = false,
}) async {
  try {
    final token = await _getToken();

    final response = await http
        .post(
          _uri('/Medicines'),
          headers: _headers(token ?? ''),
          body: jsonEncode(
            _medicineBody(
              doctorId: doctorId,
              name: name,
              generic: generic,
              brand: brand,
              group: group,
              doseForm: doseForm,
              strength: strength,
              customDosage: customDosage,
              customFrequency: customFrequency,
              customDuration: customDuration,
              customInstructions: customInstructions,
              sellingPrice: sellingPrice,
              costPrice: costPrice,
              isFavorite: isFavorite,
            ),
          ),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      final data = jsonDecode(response.body);

      return {
        'success': true,
        'serverId':
            data['id'] ??
            data['Id'] ??
            data['serverId'],
      };
    }

    return {
      'success': false,
      'error':
          'Medicine create failed: '
          '${response.statusCode} ${response.body}',
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

  Future<Map<String, dynamic>> updateMedicine({
  required int serverId,
  required String name,
  String? generic,
  String? brand,
  String? group,
  String? doseForm,
  String? strength,
  String? customDosage,
  String? customFrequency,
  String? customDuration,
  String? customInstructions,
  double sellingPrice = 0,
  double costPrice = 0,
  bool isFavorite = false,
}) async {
  try {
    final token = await _getToken();

    final response = await http
        .put(
          _uri('/Medicines/$serverId'),
          headers: _headers(token ?? ''),
          body: jsonEncode(
            _medicineBody(
              serverId: serverId,
              name: name,
              generic: generic,
              brand: brand,
              group: group,
              doseForm: doseForm,
              strength: strength,
              customDosage: customDosage,
              customFrequency: customFrequency,
              customDuration: customDuration,
              customInstructions: customInstructions,
              sellingPrice: sellingPrice,
              costPrice: costPrice,
              isFavorite: isFavorite,
            ),
          ),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return {
        'success': true,
        'serverId':
            data['id'] ??
            data['Id'] ??
            data['serverId'] ??
            serverId,
      };
    }

    return {
      'success': false,
      'error':
          'Medicine update failed: '
          '${response.statusCode} ${response.body}',
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

  Future<Map<String, dynamic>> deleteMedicine({
    required int serverId,
  }) async {
    try {
      final token = await _getToken();

      final response = await http
          .delete(
            _uri('/Medicines/$serverId'),
            headers: _headers(token ?? ''),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'success': true,
        };
      }

      return {
        'success': false,
        'error':
            'Medicine delete failed: '
            '${response.statusCode} ${response.body}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

 Future<List<dynamic>> getMedicines({
  int page = 1,
  int pageSize = 100,
  String? updatedAfter,
}) async {
  try {
    final token = await _getToken();

    final query =
        '/Medicines?page=$page&pageSize=$pageSize'
        '${updatedAfter != null ? '&updatedAfter=$updatedAfter' : ''}';

    final response = await http
        .get(
          _uri(query),
          headers: _headers(token ?? ''),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['data'] != null) {
        return decoded['data'] as List<dynamic>;
      }

      return decoded as List<dynamic>;
    }

    return [];
  } catch (e) {
    print('Get medicines error: $e');
    return [];
  }
}
}