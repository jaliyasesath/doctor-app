import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_exception.dart';

class OfflineFallbackPolicy {
  OfflineFallbackPolicy._();

  static bool isAllowed(Object error) {
    if (error is AppException) {
      return error.canUseOfflineFallback || error.code == 'OFFLINE_MODE';
    }

    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }

  static void rethrowUnlessAllowed(Object error) {
    if (!isAllowed(error)) {
      throw error;
    }
  }
}
