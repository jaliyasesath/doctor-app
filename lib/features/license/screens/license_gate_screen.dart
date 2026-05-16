import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/screens/login_screen.dart';
import '../data/license_service.dart';
import 'license_activate_screen.dart';

class LicenseGateScreen extends StatefulWidget {
  const LicenseGateScreen({super.key});

  @override
  State<LicenseGateScreen> createState() => _LicenseGateScreenState();
}

class _LicenseGateScreenState extends State<LicenseGateScreen> {
  bool _loading = true;
  bool _activated = false;
  bool _expired = false;
  bool _deviceAuthorized = true;
  Duration _remaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    await LicenseService.ensureInstallTime();

    final activated = await LicenseService.isActivated();
    final expired = await LicenseService.isTrialExpired();
    final remaining = await LicenseService.getRemainingTrialTime();
    final deviceAuthorized = await LicenseService.isCurrentDeviceAuthorized();

    if (!mounted) return;

    setState(() {
      _activated = activated;
      _expired = expired;
      _remaining = remaining ?? Duration.zero;
      _deviceAuthorized = deviceAuthorized;
      _loading = false;
    });

    if (!activated && !expired) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final expired = await LicenseService.isTrialExpired();
      final remaining = await LicenseService.getRemainingTrialTime();

      if (!mounted) return;

      setState(() {
        _expired = expired;
        _remaining = remaining ?? Duration.zero;
      });

      if (expired) {
        _timer?.cancel();
      }
    });
  }

  Future<void> _openActivation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LicenseActivateScreen(),
      ),
    );

    if (result == true) {
      await _loadStatus();
    }
  }

  Future<void> _resetTrialForTesting() async {
    await LicenseService.clearLicenseForTesting();
    await _loadStatus();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trial reset for testing')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activated && !_deviceAuthorized) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phonelink_lock_outlined,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'License Device Mismatch',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This license is bound to another device.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _resetTrialForTesting,
                        child: const Text('Reset Trial (Testing)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_activated) {
      return const LoginScreen();
    }

    if (_expired) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_clock_outlined,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Trial Expired',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your trial period has ended. Enter your lifetime license key to continue using the app.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _openActivation,
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Activate License'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _resetTrialForTesting,
                        child: const Text('Reset Trial (Testing)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 60,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Trial Active',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Time remaining: ${LicenseService.formatDuration(_remaining)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text('Continue Trial'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _openActivation,
                      child: const Text('Activate Lifetime License'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resetTrialForTesting,
                      child: const Text('Reset Trial (Testing)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}