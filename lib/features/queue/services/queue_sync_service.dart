import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../patient/data/api_patient_service.dart';

class QueueSyncService {
  QueueSyncService._();

  static final QueueSyncService instance = QueueSyncService._();

  static const int _batchSize = 100;
  Future<void>? _activeSync;

  Future<void> syncChanges() {
    final current = _activeSync;
    if (current != null) return current;

    final future = _runSync();
    _activeSync = future;
    return future.whenComplete(() {
      if (identical(_activeSync, future)) {
        _activeSync = null;
      }
    });
  }

  Future<void> _runSync() async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    if (doctorId == null || doctorId <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final timeKey = 'queue_sync_cursor_time_$doctorId';
    final idKey = 'queue_sync_cursor_id_$doctorId';

    String? cursorTime = prefs.getString(timeKey);
    var cursorId = prefs.getInt(idKey) ?? 0;

    // A safety ceiling prevents a malformed server response from creating an
    // endless background loop. 1000 × 100 is far above the queue target.
    for (var batch = 0; batch < 1000; batch++) {
      final page = await ApiPatientService().getQueueChanges(
        afterTime: cursorTime,
        afterId: cursorId,
        pageSize: _batchSize,
      );

      await _cache(page.data, doctorId);

      if (page.nextCursorTime.isNotEmpty) {
        cursorTime = page.nextCursorTime;
        cursorId = page.nextCursorId;

        // Save the cursor only after the complete batch was committed to
        // SQLite. A crash before this point safely downloads the batch again.
        await prefs.setString(timeKey, cursorTime);
        await prefs.setInt(idKey, cursorId);
      }

      if (!page.hasMore) return;
    }

    throw StateError('Queue synchronization exceeded its safety limit.');
  }

  Future<void> _cache(List<dynamic> data, int doctorId) async {
    if (data.isEmpty) return;

    await DatabaseHelper.instance.cacheQueuePatientsFromServer(
      doctorId: doctorId,
      patients: data,
    );
  }

  Future<void> resetCursor() async {
    final doctorId = await DoctorSession.getActiveDoctorIdForData();
    if (doctorId == null || doctorId <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('queue_sync_cursor_time_$doctorId');
    await prefs.remove('queue_sync_cursor_id_$doctorId');
  }
}
