import '../../../core/errors/api_error_classifier.dart';
import '../../../core/errors/app_exception.dart';
import '../../net_service/api_client.dart';

class ApiInstructionService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> createInstruction({
    required int doctorId,
    required String instructionText,
  }) async {
    try {
      final response = await _api.post(
        '/CustomInstructions',
        {
          'doctorId': doctorId,
          'instructionText': instructionText,
        },
      );

      if (response is! Map) {
        throw ApiErrorClassifier.invalidResponse(
          operation: 'POST /CustomInstructions',
        );
      }

      final data = Map<String, dynamic>.from(response);
      final rawId = data['id'] ?? data['Id'] ?? data['serverId'];
      final serverId =
          rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

      if (serverId == null || serverId <= 0) {
        throw ApiErrorClassifier.invalidResponse(
          operation: 'POST /CustomInstructions',
        );
      }

      return {
        'success': true,
        'serverId': serverId,
      };
    } on AppException catch (error) {
      return {
        'success': false,
        'error': error.userMessage,
        'code': error.code,
        'retryable': error.isRetryable,
        if (error.statusCode != null) 'statusCode': error.statusCode,
        if (error.traceId != null && error.traceId!.isNotEmpty)
          'traceId': error.traceId,
      };
    }
  }

  Future<List<dynamic>> getInstructions() async {
    final response = await _api.get('/CustomInstructions');

    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map && response['data'] is List) {
      return List<dynamic>.from(response['data'] as List);
    }

    throw ApiErrorClassifier.invalidResponse(
      operation: 'GET /CustomInstructions',
    );
  }
}
