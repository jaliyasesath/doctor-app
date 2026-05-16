import 'package:flutter/material.dart';

import 'features/license/screens/license_gate_screen.dart';
import 'features/sync/services/auto_sync_service.dart';
import 'features/net_service/connection_mode_service.dart';
import 'features/net_service/auto_api_resolver.dart';
import 'features/notifications/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalNotificationService.init();
  await ConnectionModeService.loadSavedMode();
  await AutoApiResolver.resolve();

  AutoSyncService.start();

  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const LicenseGateScreen(),
    );
  }
}