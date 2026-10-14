import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'client/pp_client_app.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // This entry point never initializes the doctor database, hotspot or sync.
    FlutterError.onError = (_) { debugPrint('PP Client framework error'); };
    PlatformDispatcher.instance.onError = (_, __) {
      debugPrint('PP Client unhandled error');
      return true;
    };
    ErrorWidget.builder = (_) => const Material(
      child: Center(child: Text('Unable to display this screen. Please reopen the app.')),
    );
    if (appFlavor != 'client') {
      runApp(const MaterialApp(home: Scaffold(body: Center(
        child: Text('Build PP Client with --flavor client -t lib/main_client.dart.'),
      ))));
      return;
    }
    runApp(const PPClientApp());
  }, (_, __) { debugPrint('PP Client asynchronous error'); });
}
