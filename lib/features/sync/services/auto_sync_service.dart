import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/logging/app_logger.dart';
import '../../queue/services/queue_sync_service.dart';
import 'network_service.dart';
import 'sync_service.dart';

class AutoSyncService {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static bool _syncing = false;
  static bool _syncRequestedWhileRunning = false;
  static Completer<void>? _activeSync;

  static void start() {
    final existingSubscription = _subscription;
    if (existingSubscription != null) {
      unawaited(existingSubscription.cancel());
    }
    _subscription = Connectivity().onConnectivityChanged.listen(
      (result) async {
        if (!result.any((item) => item != ConnectivityResult.none)) return;

        try {
          await QueueSyncService.instance.syncChanges();
        } catch (error, stackTrace) {
          AppErrorHandler.recordUnawaited(
            error,
            stackTrace,
            source: 'AutoSync',
            context: 'Queue recovery after connectivity restore',
          );
        }

        await syncPendingChanges();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppErrorHandler.recordUnawaited(
          error,
          stackTrace,
          source: 'AutoSync',
          context: 'Connectivity stream',
        );
      },
    );
  }

  static Future<void> syncPendingChanges() async {
    if (_syncing) {
      _syncRequestedWhileRunning = true;
      await _activeSync?.future;
      return;
    }

    final hasPending = await SyncService().hasPendingLocalChanges();
    if (!hasPending) return;

    _syncing = true;
    final completion = Completer<void>();
    _activeSync = completion;

    try {
      do {
        _syncRequestedWhileRunning = false;

        final online = await NetworkService.isOnline();
        if (!online) return;

        final pendingNow = await SyncService().hasPendingLocalChanges();
        if (!pendingNow) return;

        final result = await SyncService().syncAll();

        if (result.hasFailures || result.lastError.isNotEmpty) {
          await AppLogger.warning(
            result.lastError.isNotEmpty
                ? result.lastError
                : 'Sync completed with one or more failed items.',
            source: 'AutoSync',
          );
        }
      } while (_syncRequestedWhileRunning);
    } catch (error, stackTrace) {
      AppErrorHandler.recordUnawaited(
        error,
        stackTrace,
        source: 'AutoSync',
        context: 'Background synchronization',
      );
    } finally {
      _syncing = false;
      if (!completion.isCompleted) completion.complete();
      if (identical(_activeSync, completion)) _activeSync = null;
    }
  }

  static Future<void> stop() async {
    await _subscription?.cancel();

    _subscription = null;
    _syncing = false;
    _syncRequestedWhileRunning = false;
    final completion = _activeSync;
    if (completion != null && !completion.isCompleted) completion.complete();
    _activeSync = null;
  }
}
