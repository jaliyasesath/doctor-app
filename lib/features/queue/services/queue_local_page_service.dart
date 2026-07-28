import '../../../data/local/database_helper.dart';

class QueueLocalPage {
  final List<Map<String, dynamic>> items;
  final bool hasMore;

  const QueueLocalPage({
    required this.items,
    required this.hasMore,
  });
}

class QueueLocalPageService {
  static const int pageSize = 30;

  Future<QueueLocalPage> getToday({
    required String status,
    required int page,
  }) async {
    final rows = await DatabaseHelper.instance.getTodayQueuePatients(
      status: status,
      limit: pageSize + 1,
      offset: (page - 1) * pageSize,
    );

    return _toPage(rows);
  }

  Future<QueueLocalPage> getPreviousPending({
    required int page,
  }) async {
    final rows = await DatabaseHelper.instance.getPreviousPendingQueuePatients(
      limit: pageSize + 1,
      offset: (page - 1) * pageSize,
    );

    return _toPage(rows);
  }

  QueueLocalPage _toPage(List<Map<String, dynamic>> rows) {
    final hasMore = rows.length > pageSize;
    final visibleRows = rows.take(pageSize).map(_mapPatient).toList();

    return QueueLocalPage(items: visibleRows, hasMore: hasMore);
  }

  Map<String, dynamic> _mapPatient(Map<String, dynamic> patient) {
    final serverId = int.tryParse(
      patient['server_id']?.toString() ?? '',
    );
    final localId = int.tryParse(patient['id']?.toString() ?? '');

    return {
      // Online actions require the server ID. Unsynced offline rows retain
      // their local ID so the existing offline fallback can update SQLite.
      'id': serverId ?? localId,
      'localId': localId,
      'patientCode': serverId != null
          ? (patient['patient_code']?.toString().trim().isNotEmpty == true
              ? patient['patient_code']
              : 'P$serverId')
          : 'OFF-${localId ?? 0}',
      'queueNo': patient['queue_no'] ?? localId,
      'queueStatus': patient['queue_status'] ?? 'Waiting',
      'queueDate': patient['queue_date'],
      'patientName': patient['patient_name'] ?? '',
      'patientAge': patient['patient_age'] ?? '',
      'patientGender': patient['patient_gender'] ?? '',
      'phoneNumber': patient['phone_number'] ?? '',
      'address': patient['address'] ?? '',
      'notes': patient['notes'] ?? '',
      'allergies': patient['allergies'] ?? '',
      'chronicDiseases': patient['chronic_diseases'] ?? '',
      'importantAlerts': patient['important_alerts'] ?? '',
      'version': patient['server_version'] ?? 0,
      'syncStatus': patient['sync_status'] ?? '',
    };
  }
}
