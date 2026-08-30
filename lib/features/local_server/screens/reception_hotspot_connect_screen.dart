import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../net_service/api_config.dart';
import '../../net_service/connection_mode_service.dart';
import '../../net_service/hotspot_pairing_storage.dart';

import 'package:http/http.dart' as http;

class ReceptionHotspotConnectScreen extends StatefulWidget {
  const ReceptionHotspotConnectScreen({super.key});

  @override
  State<ReceptionHotspotConnectScreen> createState() =>
      _ReceptionHotspotConnectScreenState();
}

class _ReceptionHotspotConnectScreenState
    extends State<ReceptionHotspotConnectScreen> {
  bool _scanned = false;
  String _message = 'Scan Doctor Hotspot QR';

  Future<void> _handleQr(String value) async {
    if (_scanned) return;

    setState(() {
      _scanned = true;
      _message = 'Searching Doctor local server...';
    });

    String scannedUrl;
    String pairingToken;
    DateTime? expiresAt;
    try {
      final payload = jsonDecode(value) as Map<String, dynamic>;
      scannedUrl = payload['url']?.toString().trim() ?? '';
      pairingToken = payload['token']?.toString().trim() ?? '';
      expiresAt = DateTime.tryParse(
        payload['expiresAt']?.toString() ?? '',
      )?.toUtc();
    } catch (_) {
      scannedUrl = '';
      pairingToken = '';
      expiresAt = null;
    }
    if (scannedUrl.isEmpty || pairingToken.length < 32 ||
        expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      setState(() { _scanned = false; _message = 'Invalid or old pairing QR'; });
      return;
    }

    final possibleUrls = [scannedUrl];

    for (final url in possibleUrls) {
      try {
        final alive = await _isServerAlive(url, pairingToken);

        if (!alive) {
          continue;
        }

        ApiConfig.setHotspotBaseUrl(url);
        ApiConfig.setHotspotPairingToken(pairingToken, expiresAt: expiresAt);
        await HotspotPairingStorage.save(
          url: url,
          token: pairingToken,
          expiresAt: expiresAt,
        );
        await ConnectionModeService.setReceptionHotspotMode();

        if (!mounted) return;

        setState(() {
          _message = 'Connected:\n$url';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connected to Doctor Server ✅',
            ),
          ),
        );

        Navigator.pop(context, true);

        return;
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _scanned = false;
      _message = 'Unable to find Doctor local server';
    });
  }

  Future<bool> _isServerAlive(String url, String pairingToken) async {
    try {
      final root = url.replaceAll('/api', '');

      final response = await http
          .get(Uri.parse('$root/api/Health'), headers: {
            'X-Clinic-Pairing-Token': pairingToken,
          })
          .timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Connect Doctor Hotspot'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;

                if (barcodes.isEmpty) return;

                final value = barcodes.first.rawValue;

                if (value == null || value.trim().isEmpty) return;

                _handleQr(value.trim());
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 42,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan the QR shown on Doctor phone Hotspot QR screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
