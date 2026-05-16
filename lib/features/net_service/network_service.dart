import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();

    if (result is List<ConnectivityResult>) {
      return !result.contains(ConnectivityResult.none);
    }

    return result != ConnectivityResult.none;
  }
}