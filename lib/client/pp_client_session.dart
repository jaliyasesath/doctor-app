import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'pp_client_config.dart';
import 'pp_client_identity_display.dart';

/// Serializes all session mutations: no overlapping refresh, logout or login.
/// Only a single session JSON record is persisted; profile stays in memory.
class PPClientSession extends ChangeNotifier {
  PPClientSession({http.Client? transport}) : _http = transport ?? http.Client();
  final http.Client _http;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _storageKey = 'pp_client_identity_session_v1';
  static const _photoKey = 'pp_client_google_photo_v1';
  String? _googlePhotoUrl;
  String? get googlePhotoUrl => _googlePhotoUrl;
  Future<void> _tail = Future<void>.value();
  Future<void>? _googleInitialization;
  String? _access, _refresh;
  DateTime? _expires;
  Map<String, dynamic>? profile;
  bool get signedIn => _refresh != null;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<http.Response> _send(String method, String action,
      {Map<String, dynamic>? body, String? bearer}) async {
    final request = http.Request(method, PPClientConfig.endpoint(action));
    // Never follow an API redirect carrying an Authorization header.
    request.followRedirects = false;
    request.headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json',
      if (bearer != null) 'Authorization': 'Bearer $bearer'});
    if (body != null) request.body = jsonEncode(body);
    try {
      return await (() async => http.Response.fromStream(await _http.send(request)))()
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const PPClientError('The connection took too long. Please try again.');
    } on http.ClientException {
      throw const PPClientError('Unable to connect. Check your internet and try again.');
    }
  }

  Map<String, dynamic> _object(http.Response response) {
    if (response.statusCode == 429) {
      throw const PPClientError('Too many requests. Please wait before trying again.');
    }
    if (response.statusCode >= 500) {
      throw const PPClientError('The service is temporarily unavailable. Please try again.');
    }
    if (response.statusCode == 409) {
      throw const PPClientError('The queue changed or this booking is unavailable. Refresh and try again.');
    }
    if (response.statusCode == 404) {
      throw const PPClientError('Patient access is unavailable on this API.');
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const PPClientError('The API connection must use its final secure address.');
    }
    dynamic data;
    try { data = jsonDecode(response.body); } on FormatException {
      throw const PPClientError('The service returned an unexpected response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Do not display arbitrary backend exception details or SQL messages.
      throw const PPClientError('Unable to complete this request. Check your details and try again.');
    }
    if (data is! Map<String, dynamic>) {
      throw const PPClientError('The service returned an unexpected response.');
    }
    return data;
  }

  Future<void> _clear() async {
    _access = null; _refresh = null; _expires = null; profile = null;
    _googlePhotoUrl = null;
    notifyListeners();
    await _storage.delete(key: _storageKey);
    try { await _storage.delete(key: _photoKey); } catch (_) { /* Optional display metadata only. */ }
  }

  Future<void> _accept(Map<String, dynamic> data) async {
    final access = data['accessToken'], refresh = data['refreshToken'];
    final expires = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    final p = data['profile'];
    if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty ||
        expires == null || p is! Map<String, dynamic>) {
      throw const PPClientError('The sign-in response was incomplete. Please sign in again.');
    }
    try {
      await _storage.write(key: _storageKey, value: jsonEncode({
        'origin': PPClientConfig.origin.toString(), 'access': access,
        'refresh': refresh, 'expires': expires.toUtc().toIso8601String(),
      }));
    } catch (_) {
      // Rotation may already have committed server-side: fail closed locally.
      _access = null; _refresh = null; _expires = null; profile = null;
    _googlePhotoUrl = null;
      notifyListeners();
      throw const PPClientError('Secure session storage failed. Please sign in again.');
    }
    if (profile?['patientAccountId'] != p['patientAccountId']) { _googlePhotoUrl = null; }
    _access = access; _refresh = refresh; _expires = expires; profile = p;
    notifyListeners();
  }

  Future<void> _rotate() async {
    final token = _refresh;
    if (token == null) throw const PPClientError('Please sign in again.');
    final response = await _send('POST', 'refresh', body: {'refreshToken': token});
    if ([401, 403].contains(response.statusCode)) {
      await _clear();
      throw const PPClientError('Your session has ended. Please sign in again.');
    }
    await _accept(_object(response));
  }

  Future<Map<String, dynamic>> _authorized(String method, String action,
      {Map<String, dynamic>? body}) async {
    if (_access == null) throw const PPClientError('Please sign in again.');
    if (_expires == null || _expires!.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
      await _rotate();
    }
    var response = await _send(method, action, body: body, bearer: _access);
    if (response.statusCode == 401) {
      await _rotate();
      response = await _send(method, action, body: body, bearer: _access);
    }
    if ([401, 403].contains(response.statusCode)) {
      await _clear();
      throw const PPClientError('Your session has ended. Please sign in again.');
    }
    if (response.statusCode == 204) return <String, dynamic>{};
    return _object(response);
  }

  Future<void> restore() => _serial(() async {
    PPClientConfig.origin; // validate before reading or sending stored credentials
    final stored = await _storage.read(key: _storageKey);
    if (stored == null) return;
    dynamic data;
    try { data = jsonDecode(stored); } on FormatException { await _clear(); return; }
    if (data is! Map<String, dynamic> || data['origin'] != PPClientConfig.origin.toString() ||
        data['access'] is! String || data['refresh'] is! String || data['expires'] is! String) {
      await _clear(); return;
    }
    _access = data['access'] as String; _refresh = data['refresh'] as String;
    _expires = DateTime.tryParse(data['expires'] as String);
    profile = await _authorized('GET', 'profile');
    await _restoreGooglePhoto();
    notifyListeners();
  });

  Future<void> _restoreGooglePhoto() async {
    _googlePhotoUrl = null;
    try {
      final stored = await _storage.read(key: _photoKey);
      if (stored == null) return;
      final data = jsonDecode(stored);
      if (data is Map<String, dynamic> &&
          data['origin'] == PPClientConfig.origin.toString() &&
          data['patientAccountId'] == profile?['patientAccountId']) {
        _googlePhotoUrl = ppClientPhotoUrl(data['url']);
      }
    } catch (_) { /* A missing photo must never prevent session restore. */ }
  }

  Future<void> _saveGooglePhoto(String? value) async {
    _googlePhotoUrl = ppClientPhotoUrl(value);
    notifyListeners();
    try {
      await _storage.write(key: _photoKey, value: jsonEncode({
        'origin': PPClientConfig.origin.toString(),
        'patientAccountId': profile?['patientAccountId'],
        'url': _googlePhotoUrl,
      }));
    } catch (_) { /* Photo caching is optional; authentication already succeeded. */ }
  }

  Future<void> signInWithGoogle() => _serial(() async {
    PPClientConfig.origin;
    if (!PPClientConfig.googleWebClientId.endsWith('.apps.googleusercontent.com')) {
      throw const PPClientError('Google sign-in is not configured yet.');
    }
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      throw const PPClientError('Patient Google sign-in is supported on Android and iOS.');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && PPClientConfig.googleIosClientId.isEmpty) {
      throw const PPClientError('iOS Google sign-in configuration is required.');
    }
    final google = GoogleSignIn.instance;
    _googleInitialization ??= google.initialize(
      serverClientId: PPClientConfig.googleWebClientId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? PPClientConfig.googleIosClientId : null,
    );
    try {
      await _googleInitialization;
      final user = await google.authenticate();
      final token = user.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const PPClientError('Google could not verify this account. Please try again.');
      }
      final response = await _send('POST', 'google', bearer: token);
      if ([401, 403].contains(response.statusCode)) {
        throw const PPClientError('This Google account could not sign in. Please check the configuration.');
      }
      await _accept(_object(response));
      await _saveGooglePhoto(user.photoUrl);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const PPClientError('Sign-in was cancelled.');
      }
      throw const PPClientError('Google sign-in failed. Check the app registration and try again.');
    }
  });

  Future<void> reloadProfile() => _serial(() async {
    profile = await _authorized('GET', 'profile'); notifyListeners();
  });

  Future<void> updateProfile(Map<String, dynamic> body) => _serial(() async {
    profile = await _authorized('PUT', 'profile', body: body); notifyListeners();
  });

  Future<void> logout() => _serial(() async {
    // Retain the session if revocation fails: the user can retry explicitly.
    await _authorized('POST', 'logout');
    await _clear();
    if (_googleInitialization != null) {
      try { await GoogleSignIn.instance.signOut(); } catch (_) { /* API session already revoked */ }
    }
  });

  Future<Map<String, dynamic>> findDoctors({double? latitude, double? longitude, String search = '', int page = 1}) => _serial(() async {
    final query = Uri(queryParameters: {'page': '$page', 'pageSize': '20',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (latitude != null && longitude != null) 'latitude': '$latitude',
      if (latitude != null && longitude != null) 'longitude': '$longitude'}).query;
    return _authorized('GET', '/api/client/doctors?$query');
  });
  Future<Map<String, dynamic>> doctorDetails(int id) => _serial(() => _authorized('GET', '/api/client/doctors/$id'));
  Future<Map<String, dynamic>> bookDoctor(int id, String requestId) => _serial(() => _authorized('POST', '/api/client/bookings',
    body: {'doctorId': id, 'requestId': requestId}));
  Future<Map<String, dynamic>> myBookings({int page = 1}) => _serial(() => _authorized('GET', '/api/client/bookings?page=$page&pageSize=20'));
  Future<Map<String, dynamic>> cancelBooking(int id) => _serial(() => _authorized('POST', '/api/client/bookings/$id/cancel'));

  @override
  void dispose() { _http.close(); super.dispose(); }
}
