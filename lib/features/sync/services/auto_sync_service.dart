import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/logging/app_logger.dart';
import '../../queue/services/queue_sync_service.dart';
import 'network_service.dart';
import 'sync_service.dart';

class AutoSyncService {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static Timer? _recoveryTimer;
  static int _recoveryGeneration = 0;

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
        scheduleRecovery();
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

    // Connectivity streams do not always emit an initial event. This also
    // recovers records left pending when the application was closed offline.
    scheduleRecovery();
  }

  /// Retries while a newly enabled connection is still obtaining internet
  /// access. Repeated calls safely replace the previous retry sequence.
  static void scheduleRecovery() {
    _recoveryTimer?.cancel();
    final generation = ++_recoveryGeneration;
    _recoveryTimer = Timer(const Duration(seconds: 1), () {
      unawaited(_recoverWithRetry(generation));
    });
  }

  static Future<void> _recoverWithRetry(int generation) async {
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ];

    for (final delay in retryDelays) {
      if (generation != _recoveryGeneration) return;
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (generation != _recoveryGeneration) return;

      try {
        // Queue recovery must never prevent patient/prescription recovery.
        // They use different endpoints and can fail independently.
        try {
          await QueueSyncService.instance.syncChanges();
        } catch (error, stackTrace) {
          AppErrorHandler.recordUnawaited(
            error,
            stackTrace,
            source: 'AutoSync',
            context: 'Queue recovery attempt',
          );
        }

        // Connectivity already reported an available transport. Let the real
        // API request decide whether the server is reachable instead of
        // blocking all pending records behind a transient health-check race.
        await syncPendingChanges(networkConfirmed: true);

        if (!await SyncService().hasPendingLocalChanges()) return;
      } catch (error, stackTrace) {
        AppErrorHandler.recordUnawaited(
          error,
          stackTrace,
          source: 'AutoSync',
          context: 'Connectivity recovery attempt',
        );
      }
    }
  }

  static Future<void> syncPendingChanges({bool networkConfirmed = false}) async {
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

        if (!networkConfirmed) {
          final online = await NetworkService.isOnline();
          if (!online) return;
        }

        final pendingNow = await SyncService().hasPendingLocalChanges();
        if (!pendingNow) return;

        final result = await SyncService().syncAll(
          networkConfirmed: networkConfirmed,
        );

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
    _recoveryTimer?.cancel();

    _subscription = null;
    _recoveryTimer = null;
    _recoveryGeneration++;
    _syncing = false;
    _syncRequestedWhileRunning = false;
    final completion = _activeSync;
    if (completion != null && !completion.isCompleted) completion.complete();
    _activeSync = null;
  }
}
