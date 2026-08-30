import 'dart:convert';

import 'package:http/http.dart' as base;
export 'package:http/http.dart' show Response;

import 'api_client.dart';
import 'token_storage.dart';
import 'api_config.dart';
import '../../core/concurrency/single_flight.dart';

final SingleFlight _postSingleFlight = SingleFlight();
int _postSequence = 0;

Future<Map<String, String>> _freshHeaders(Map<String, String>? headers) async {
  final updated = <String, String>{...?headers};
  if (ApiConfig.isHotspot && ApiConfig.hasValidHotspotPairing) {
    updated['X-Clinic-Pairing-Token'] = ApiConfig.hotspotPairingToken;
  }
  final token = await TokenStorage.getToken();
  if (token != null && token.isNotEmpty) {
    updated['Authorization'] = 'Bearer $token';
  }
  return updated;
}

Future<base.Response> _withRefresh(
  Future<base.Response> Function(Map<String, String> headers) send,
  Map<String, String>? headers,
) async {
  var response = await send(await _freshHeaders(headers));
  if (response.statusCode == 401 && await ApiClient.refreshSession()) {
    response = await send(await _freshHeaders(headers));
  }
  return response;
}

Future<base.Response> get(Uri url, {Map<String, String>? headers}) =>
    _withRefresh((fresh) => base.get(url, headers: fresh), headers);

Future<base.Response> delete(Uri url, {Map<String, String>? headers}) =>
    _withRefresh((fresh) => base.delete(url, headers: fresh), headers);

Future<base.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  final requestHeaders = <String, String>{...?headers};
  requestHeaders['Idempotency-Key'] ??=
      'mobile-${DateTime.now().microsecondsSinceEpoch}-${++_postSequence}';
  final key = 'POST|$url|${body?.toString() ?? ''}';
  return _postSingleFlight.run<base.Response>(
    key,
    () => _withRefresh(
      (fresh) => base.post(
        url,
        headers: fresh,
        body: body,
        encoding: encoding,
      ),
      requestHeaders,
    ),
  );
}

Future<base.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    _withRefresh(
      (fresh) => base.put(
        url,
        headers: fresh,
        body: body,
        encoding: encoding,
      ),
      headers,
    );
