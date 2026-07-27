import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();

      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
