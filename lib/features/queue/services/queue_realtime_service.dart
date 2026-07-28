import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../net_service/api_config.dart';
import '../../net_service/token_storage.dart';
import 'queue_sync_service.dart';

class QueueRealtimeService {
  QueueRealtimeService._();

  static final QueueRealtimeService instance = QueueRealtimeService._();

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  HubConnection? _connection;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _connectionUrl;
  bool _started = false;
  bool _connecting = false;

  Stream<Map<String, dynamic>> get events => _events.stream;

  static String? hubUrlFor(String apiBaseUrl) {
    final clean = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (clean.isEmpty) return null;

    return '$clean/hubs/queue';
  }

  Future<void> connect() async {
    if (_connecting) return;

    _ensureConnectivityListener();

    // The local phone hotspot server is a Shelf server, not the ASP.NET API,
    // so SignalR is available only for cloud/local-Wi-Fi API modes.
    if (ApiConfig.isOffline || ApiConfig.isHotspot) {
      await _stopConnection();
      return;
    }

    final hubUrl = hubUrlFor(ApiConfig.baseUrl);
    if (hubUrl == null) {
      await _stopConnection();
      return;
    }

    if (_started && _connectionUrl == hubUrl) return;

    _connecting = true;
    try {
      await _stopConnection();

      final connection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  await TokenStorage.getToken() ?? '',
              requestTimeout: 10000,
            ),
          )
          .withAutomaticReconnect()
          .build();

      connection.on('QueueChanged', _handleQueueChanged);
      connection.onclose(({error}) {
        _started = false;
      });
      connection.onreconnecting(({error}) {
        _started = false;
      });
      connection.onreconnected(({connectionId}) {
        _started = true;
      });

      _connection = connection;
      _connectionUrl = hubUrl;

      await connection.start();
      _started = true;
    } catch (_) {
      _started = false;
      // The existing REST + SQLite + pull-to-refresh flow remains the
      // fallback when the realtime channel cannot connect.
    } finally {
      _connecting = false;
    }
  }

  void _ensureConnectivityListener() {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork =
          results.any((result) => result != ConnectivityResult.none);
      if (!hasNetwork || _started || _connecting) return;

      unawaited(connect());
    });
  }

  void _handleQueueChanged(List<Object?>? arguments) {
    Map<String, dynamic> event;
    if (arguments == null || arguments.isEmpty) {
      event = const {'action': 'changed'};
    } else {
      final payload = arguments.first;
      event = payload is Map
          ? Map<String, dynamic>.from(payload)
          : const {'action': 'changed'};
    }

    unawaited(_syncThenEmit(event));
  }

  Future<void> _syncThenEmit(Map<String, dynamic> event) async {
    try {
      await QueueSyncService.instance.syncChanges();
    } catch (_) {
      // The screen still receives the event and can show its current local
      // cache. App resume/connectivity recovery will retry the delta sync.
    } finally {
      _events.add(event);
    }
  }

  Future<void> disconnect() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _stopConnection();
  }

  Future<void> _stopConnection() async {
    final connection = _connection;
    _connection = null;
    _connectionUrl = null;
    _started = false;

    if (connection == null) return;

    try {
      connection.off('QueueChanged', method: _handleQueueChanged);
      await connection.stop();
    } catch (_) {
      // Disconnect is best-effort and must not interrupt navigation/logout.
    }
  }
}
