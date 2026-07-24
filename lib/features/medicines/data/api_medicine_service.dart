import '../../../core/errors/api_error_classifier.dart';
import '../../../core/errors/app_exception.dart';
import '../../net_service/api_client.dart';

class ApiMedicineService {
  final ApiClient _api = ApiClient();

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
    String? customMedicineName,
    String? customGenericName,
    String? customBrandName,
    String? customDrugGroup,
    String? customMedicineType,
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
      'customMedicineName': customMedicineName ?? '',
      'customGenericName': customGenericName ?? '',
      'customBrandName': customBrandName ?? '',
      'customDrugGroup': customDrugGroup ?? '',
      'customMedicineType': customMedicineType ?? '',
      'isFavorite': isFavorite,
      'isGlobal': false,
      'assignedDoctorIds': <int>[],
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
    String? customMedicineName,
    String? customGenericName,
    String? customBrandName,
    String? customDrugGroup,
    String? customMedicineType,
    double sellingPrice = 0,
    double costPrice = 0,
    bool isFavorite = false,
  }) async {
    try {
      final response = await _api.post(
        '/Medicines',
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
          customMedicineName: customMedicineName,
          customGenericName: customGenericName,
          customBrandName: customBrandName,
          customDrugGroup: customDrugGroup,
          customMedicineType: customMedicineType,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          isFavorite: isFavorite,
        ),
      );

      return _successResult(response);
    } on AppException catch (error) {
      return _failureResult(error);
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
    String? customMedicineName,
    String? customGenericName,
    String? customBrandName,
    String? customDrugGroup,
    String? customMedicineType,
    double sellingPrice = 0,
    double costPrice = 0,
    bool isFavorite = false,
  }) async {
    try {
      final response = await _api.put(
        '/Medicines/$serverId',
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
          customMedicineName: customMedicineName,
          customGenericName: customGenericName,
          customBrandName: customBrandName,
          customDrugGroup: customDrugGroup,
          customMedicineType: customMedicineType,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          isFavorite: isFavorite,
        ),
      );

      return _successResult(response, fallbackServerId: serverId);
    } on AppException catch (error) {
      return _failureResult(error);
    }
  }

  Future<Map<String, dynamic>> deleteMedicine({
    required int serverId,
  }) async {
    try {
      await _api.delete('/Medicines/$serverId');
      return {'success': true};
    } on AppException catch (error) {
      return _failureResult(error);
    }
  }

  Future<List<dynamic>> getMedicines({
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _api.get(
      '/Medicines?page=$page&pageSize=$pageSize',
    );
    return _readList(response, operation: 'GET /Medicines');
  }

  Future<List<dynamic>> getMedicineChanges({
    required String updatedAfter,
    int page = 1,
    int pageSize = 100,
  }) async {
    final encodedUpdatedAfter = Uri.encodeQueryComponent(updatedAfter);
    final response = await _api.get(
      '/Medicines/sync?updatedAfter=$encodedUpdatedAfter'
      '&page=$page&pageSize=$pageSize',
    );
    return _readList(response, operation: 'GET /Medicines/sync');
  }

  Map<String, dynamic> _successResult(
    dynamic response, {
    int? fallbackServerId,
  }) {
    if (response is! Map) {
      throw ApiErrorClassifier.invalidResponse(
        operation: 'Medicine write',
      );
    }

    final data = Map<String, dynamic>.from(response);
    final rawServerId =
        data['id'] ?? data['Id'] ?? data['serverId'] ?? fallbackServerId;
    final serverId = rawServerId is int
        ? rawServerId
        : int.tryParse(rawServerId?.toString() ?? '');

    if (serverId == null || serverId <= 0) {
      throw ApiErrorClassifier.invalidResponse(
        operation: 'Medicine write',
      );
    }

    return {
      'success': true,
      'serverId': serverId,
    };
  }

  List<dynamic> _readList(
    dynamic response, {
    required String operation,
  }) {
    if (response is Map && response['data'] is List) {
      return List<dynamic>.from(response['data'] as List);
    }

    if (response is List) {
      return List<dynamic>.from(response);
    }

    throw ApiErrorClassifier.invalidResponse(operation: operation);
  }

  Map<String, dynamic> _failureResult(AppException error) {
    return {
      'success': false,
      'error': error.userMessage,
      'code': error.code,
      'retryable': error.isRetryable,
      'offlineEligible': error.canUseOfflineFallback,
      if (error.statusCode != null) 'statusCode': error.statusCode,
      if (error.traceId != null && error.traceId!.isNotEmpty)
        'traceId': error.traceId,
    };
  }
}
