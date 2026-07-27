import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../local_clinic_server.dart';
import '../services/local_ip_service.dart';

class DoctorHotspotQrScreen extends StatefulWidget {
  const DoctorHotspotQrScreen({super.key});

  @override
  State<DoctorHotspotQrScreen> createState() => _DoctorHotspotQrScreenState();
}

class _DoctorHotspotQrScreenState extends State<DoctorHotspotQrScreen> {
  bool _starting = false;

  String _message = '';

  String _serverUrl = '';

  @override
  void initState() {
    super.initState();

    _startHotspotMode();
  }

  Future<void> _startHotspotMode() async {
    setState(() {
      _starting = true;
      _message = 'Starting local clinic server...';
    });

    try {
      await LocalClinicServer.start(port: 8080);

      final localUrl = await LocalIpService.getLocalApiUrl();

      if (!mounted) return;

      setState(() {
        _serverUrl = localUrl;

        _message = LocalClinicServer.isRunning
            ? 'Local server is ready. QR created.'
            : 'Local server could not be started.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _serverUrl = '';
        _message =
            'QR could not be created. Turn on the phone hotspot and tap Retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _stopServer() async {
    await LocalClinicServer.stop();

    if (!mounted) return;

    setState(() {
      _message = 'Local server stopped';
    });
  }

  Widget _infoBox({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = LocalClinicServer.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Hotspot QR'),
        actions: [
          IconButton(
            tooltip: 'Restart Server',
            icon: const Icon(Icons.refresh),
            onPressed: _starting ? null : _startHotspotMode,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: running
                    ? Colors.green.withOpacity(0.12)
                    : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(
                    running ? Icons.wifi_tethering : Icons.warning_amber,
                    size: 48,
                    color: running ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _message.isEmpty ? 'Preparing local server...' : _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: running ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _infoBox(
              icon: Icons.wifi,
              title: 'Step 1',
              text:
                  'Turn ON Doctor phone Mobile Hotspot manually from phone settings.',
            ),
            _infoBox(
              icon: Icons.phone_android,
              title: 'Step 2',
              text: 'Connect Reception phone to Doctor hotspot WiFi.',
            ),
            _infoBox(
              icon: Icons.qr_code_scanner,
              title: 'Step 3',
              text:
                  'Open Reception app and scan this QR to connect local server.',
            ),
            const SizedBox(height: 18),
            if (running && _serverUrl.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black12,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _serverUrl,
                    version: QrVersions.auto,
                    size: 240,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _starting ? null : _startHotspotMode,
              icon: _starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _starting ? 'Starting...' : 'Start / Restart Local Server',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: running ? _stopServer : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Local Server'),
            ),
          ],
        ),
      ),
    );
  }
}
