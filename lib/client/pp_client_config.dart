import 'package:flutter/foundation.dart';

/// URLs are origins with an optional deployment path, without trailing /api.
/// These public build settings never contain JWT keys or Google client secrets.
abstract final class PPClientConfig {
  static const apiUrl = String.fromEnvironment('PP_CLIENT_API_URL');
  static const googleWebClientId = String.fromEnvironment('PP_CLIENT_GOOGLE_WEB_ID');
  static const googleIosClientId = String.fromEnvironment('PP_CLIENT_GOOGLE_IOS_ID');
  static const allowLocalHttp = bool.fromEnvironment('PP_CLIENT_LOCAL_HTTP');

  static Uri get origin {
    final value = Uri.tryParse(apiUrl);
    if (value == null || !value.hasAuthority || value.userInfo.isNotEmpty ||
        value.hasQuery || value.hasFragment ||
        !['http', 'https'].contains(value.scheme)) {
      throw const PPClientError('API connection is not configured.');
    }
    final local = ['10.0.2.2', 'localhost', '127.0.0.1'].contains(value.host);
    if (value.scheme != 'https' && !(kDebugMode && allowLocalHttp && local)) {
      throw const PPClientError('A secure HTTPS API connection is required.');
    }
    return value;
  }

  static Uri endpoint(String action) {
    final base = origin.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(action.startsWith('/') ? '$base$action' : '$base/api/client/account/$action');
  }
}

class PPClientError implements Exception {
  const PPClientError(this.message);
  final String message;
  @override
  String toString() => message;
}
