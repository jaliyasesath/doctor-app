import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/logging/app_logger.dart';
import 'network_service.dart';
import 'sync_service.dart';

class AutoSyncService {
  static const Duration _normalInterval = Duration(minutes: 2);
  static const Duration _maximumBackoff = Duration(minutes: 15);

  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static Timer? _timer;

  static bool _syncing = false;
  static Duration _nextDelay = _normalInterval;
  static DateTime? _lastAttemptAt;

  static void start() {
    final existingSubscription = _subscription;
    if (existingSubscription != null) {
      unawaited(existingSubscription.cancel());
    }
    _timer?.cancel();

    _subscription = Connectivity().onConnectivityChanged.listen(
      (result) async {
        if (!result.any((item) => item != ConnectivityResult.none)) return;

        await _runSync(force: true);
        _scheduleNext();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppErrorHandler.recordUnawaited(
          error,
          stackTrace,
          source: 'AutoSync',
          context: 'Connectivity stream',
        );
        _increaseBackoff();
        _scheduleNext();
      },
    );

    _scheduleNext();
  }

  static void _scheduleNext() {
    _timer?.cancel();

    _timer = Timer(_nextDelay, () async {
      await _runSync();
      _scheduleNext();
    });
  }

  static Future<void> _runSync({bool force = false}) async {
    if (_syncing) return;

    final now = DateTime.now();
    if (!force &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < const Duration(seconds: 30)) {
      return;
    }

    try {
      final online = await NetworkService.isOnline();
      if (!online) return;

      _syncing = true;
      _lastAttemptAt = now;

      final result = await SyncService().syncAll();

      if (result.lastError.isEmpty && !result.hasFailures) {
        _nextDelay = _normalInterval;
      } else {
        await AppLogger.warning(
          result.lastError.isEmpty
              ? 'Sync completed with one or more failed items.'
              : result.lastError,
          source: 'AutoSync',
        );
        _increaseBackoff();
      }
    } catch (error, stackTrace) {
      AppErrorHandler.recordUnawaited(
        error,
        stackTrace,
        source: 'AutoSync',
        context: 'Background synchronization',
      );
      _increaseBackoff();
    } finally {
      _syncing = false;
    }
  }

  static void _increaseBackoff() {
    final doubledSeconds = _nextDelay.inSeconds * 2;
    final cappedSeconds = doubledSeconds > _maximumBackoff.inSeconds
        ? _maximumBackoff.inSeconds
        : doubledSeconds;

    _nextDelay = Duration(seconds: cappedSeconds);
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _timer?.cancel();

    _subscription = null;
    _timer = null;
    _syncing = false;
    _nextDelay = _normalInterval;
    _lastAttemptAt = null;
  }
}
