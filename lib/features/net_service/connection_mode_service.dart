import 'package:shared_preferences/shared_preferences.dart';

import '../local_server/local_clinic_server.dart';
import 'api_config.dart';
import 'hotspot_pairing_storage.dart';

class ConnectionModeService {
  static const String _key = 'connection_mode';

  // =========================
  // LOAD SAVED MODE
  // =========================

  static Future<void> loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString(_key) ?? 'auto';

    ApiConfig.setMode(savedMode);

    // restore local server if hotspot mode
    if (savedMode == 'hotspot') {
      final restoredClientPairing = await HotspotPairingStorage.restore();
      if (!restoredClientPairing) {
        await LocalClinicServer.start(port: 8080);
      }
    }
  }

  // =========================
  // SAVE MODE
  // =========================

  static Future<void> _saveMode(
    String mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_key, mode);

    ApiConfig.setMode(mode);
  }

  // =========================
  // MODES
  // =========================

  static Future<void> setCloudMode() async {
    await LocalClinicServer.stop();
    await HotspotPairingStorage.clear();

    await _saveMode('cloud');
  }

  static Future<void> setLocalWifiMode() async {
    await LocalClinicServer.stop();
    await HotspotPairingStorage.clear();

    await _saveMode('wifi');
  }

  static Future<void> setHotspotMode() async {
    await HotspotPairingStorage.clear();
    await _saveMode('hotspot');

    await LocalClinicServer.start(
      port: 8080,
    );
  }

  static Future<void> setReceptionHotspotMode() async {
    await LocalClinicServer.stop();
    await _saveMode('hotspot');
  }

  static Future<void> setOfflineMode() async {
    await LocalClinicServer.stop();
    await HotspotPairingStorage.clear();

    await _saveMode('offline');
  }

  static Future<void> setAutoMode() async {
    await LocalClinicServer.stop();
    await HotspotPairingStorage.clear();

    await _saveMode('auto');
  }

  // =========================
  // GETTERS
  // =========================

  static String getCurrentMode() {
    return ApiConfig.mode;
  }

  static String getCurrentBaseUrl() {
    return ApiConfig.baseUrl;
  }
}
