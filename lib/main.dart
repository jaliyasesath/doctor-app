import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/errors/app_error_handler.dart';
import 'core/widgets/app_error_fallback.dart';
import 'features/license/screens/license_gate_screen.dart';
import 'features/net_service/auto_api_resolver.dart';
import 'features/net_service/connection_mode_service.dart';
import 'features/queue/services/queue_realtime_service.dart';
import 'features/queue/services/queue_sync_service.dart';
import 'features/sync/services/auto_sync_service.dart';
import 'features/notifications/services/local_notification_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppErrorHandler.recordUnawaited(
        details.exception,
        details.stack ?? StackTrace.current,
        source: 'FlutterError',
        context: details.context?.toDescription(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      AppErrorHandler.recordUnawaited(
        error,
        stackTrace,
        source: 'PlatformDispatcher',
      );
      return true;
    };

    ErrorWidget.builder = (details) {
      AppErrorHandler.recordUnawaited(
        details.exception,
        details.stack ?? StackTrace.current,
        source: 'ErrorWidget',
        context: details.context?.toDescription(),
      );
      return const AppErrorFallback();
    };

    await _runStartupTask('Notifications', LocalNotificationService.init);

    await _runStartupTask(
      'LoadConnectionMode',
      ConnectionModeService.loadSavedMode,
    );
    await _runStartupTask('ResolveApi', AutoApiResolver.resolve);

    try {
      AutoSyncService.start();
    } catch (error, stackTrace) {
      AppErrorHandler.recordUnawaited(
        error,
        stackTrace,
        source: 'Startup',
        context: 'StartAutoSync',
      );
    }

    runApp(const DoctorApp());
  }, (error, stackTrace) {
    AppErrorHandler.recordUnawaited(
      error,
      stackTrace,
      source: 'RunZone',
    );
  });
}

Future<void> _runStartupTask(
  String name,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (error, stackTrace) {
    AppErrorHandler.recordUnawaited(
      error,
      stackTrace,
      source: 'Startup',
      context: name,
    );
  }
}

class DoctorApp extends StatefulWidget {
  const DoctorApp({super.key});

  @override
  State<DoctorApp> createState() => _DoctorAppState();
}

class _DoctorAppState extends State<DoctorApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(QueueRealtimeService.instance.connect());
    unawaited(QueueSyncService.instance.syncChanges());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LicenseGateScreen(),
    );
  }
}
