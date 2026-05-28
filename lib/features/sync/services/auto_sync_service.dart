import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'network_service.dart';
import 'sync_service.dart';

class AutoSyncService {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static Timer? _timer;

  static bool _syncing = false;

  static void start() {
    _subscription?.cancel();
    _timer?.cancel();

    _subscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      await _runSync();
    });

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        await _runSync();
      },
    );
  }

  static Future<void> _runSync() async {
    if (_syncing) return;

    final online = await NetworkService.isOnline();

    if (!online) return;

    try {
      _syncing = true;

      final sync = SyncService();
      final res = await sync.syncAll();

      print('AUTO SYNC DONE');
      print('Patients synced: ${res.patientSuccess}');
      print('Prescriptions synced: ${res.prescriptionSuccess}');
      
    } catch (e) {
      print('AUTO SYNC ERROR: $e');
    } finally {
      _syncing = false;
    }
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _timer?.cancel();

    _subscription = null;
    _timer = null;
  }
}