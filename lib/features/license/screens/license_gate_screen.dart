import '../../../core/errors/app_error_handler.dart';
import '../../../core/widgets/desktop_auth_frame.dart';
import 'dart:io';
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
  String? _desktopStatusError;
  bool _loading = true;
  bool _activated = false;
  bool _expired = false;
  bool _deviceAuthorized = true;
  bool _subscriptionActive = false;
  bool _checkingSubscription = false;
  bool _timerTickRunning = false;

  Duration _remaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _desktopLoadStatus();
    } else {
      _loadStatus();
    }
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
    final subscriptionActive = await LicenseService.hasActiveSubscription();

    if (!mounted) return;

    setState(() {
      _activated = activated;
      _expired = expired;
      _remaining = remaining ?? Duration.zero;
      _deviceAuthorized = deviceAuthorized;
      _subscriptionActive = subscriptionActive;
      _loading = false;
    });

    if (!activated && !subscriptionActive && !expired) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        if (_timerTickRunning) return;
        _timerTickRunning = true;
        try {
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
        } catch (error) {
          if (!Platform.isWindows) rethrow;
          _timer?.cancel();
          if (mounted) setState(() {
            _desktopStatusError = 'Trial status could not be checked. Please retry.';
          });
        } finally {
          _timerTickRunning = false;
        }
      },
    );
  }

  Future<void> _openActivation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LicenseActivateScreen(),
      ),
    );

    if (result == true) {
      if (Platform.isWindows) {
        await _desktopLoadStatus();
      } else {
        await _loadStatus();
      }
    }
  }

  Future<void> _refreshSubscription() async {
    setState(() {
      _checkingSubscription = true;
    });

    final active = await LicenseService.hasActiveSubscription();

    if (!mounted) return;

    setState(() {
      _subscriptionActive = active;
      _checkingSubscription = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          active ? 'Subscription active' : 'No active subscription found',
        ),
      ),
    );
  }

  Future<void> _desktopLoadStatus() async {
    _timer?.cancel();
    if (mounted) setState(() {
      _loading = true;
      _desktopStatusError = null;
    });
    try {
      await _loadStatus();
    } catch (_, stackTrace) {
      AppErrorHandler.recordUnawaited(StateError('desktop_auth_operation'),
          stackTrace, source: 'DesktopAuthentication');
      if (mounted) setState(() {
        _loading = false;
        _desktopStatusError = 'License status could not be loaded. Please retry.';
      });
    }
  }

  Future<void> _desktopRefreshSubscription() async {
    if (_checkingSubscription) return;
    try {
      await _refreshSubscription();
    } catch (_, stackTrace) {
      AppErrorHandler.recordUnawaited(StateError('desktop_auth_operation'),
          stackTrace, source: 'DesktopAuthentication');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Subscription could not be checked. Please retry.'),
      ));
    } finally {
      if (mounted) setState(() => _checkingSubscription = false);
    }
  }

  Widget _buildDesktopGate() {
    if (!_loading && _desktopStatusError == null &&
        ((_activated && _deviceAuthorized) || _subscriptionActive) &&
        !(_activated && !_deviceAuthorized)) return const LoginScreen();
    final mismatch = _activated && !_deviceAuthorized;
    return DesktopAuthFrame(
      title: _loading ? 'Checking license'
          : _desktopStatusError != null ? 'License check unavailable'
          : mismatch ? 'License device mismatch'
          : _expired ? 'Trial expired' : 'Trial active',
      subtitle: mismatch
          ? 'This license is bound to another device. Contact the administrator.'
          : 'View your trial status or activate your license to continue.',
      busy: _checkingSubscription,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loading) const Center(child: CircularProgressIndicator())
        else if (_desktopStatusError != null) ...[
          Text(_desktopStatusError!),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _desktopLoadStatus,
              icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ] else if (!mismatch) ...[
          Text(_expired ? 'Your trial period has ended.'
              : 'Time remaining: ${LicenseService.formatDuration(_remaining)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          if (!_expired) ...[
            FilledButton(onPressed: _checkingSubscription ? null : () {
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => const LoginScreen()));
            }, child: const Text('Continue trial')),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _checkingSubscription ? null : _desktopRefreshSubscription,
            icon: _checkingSubscription
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(_checkingSubscription ? 'Checking...' : 'Refresh subscription')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _checkingSubscription ? null : _openActivation,
              icon: const Icon(Icons.verified_outlined), label: const Text('Activate license')),
          const SizedBox(height: 16),
          const Text('Monthly / Yearly plans: contact the administrator after payment.'),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) return _buildDesktopGate();
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // License is activated, but this device is not authorized.
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
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This license is bound to another device. '
                        'Please contact the administrator for assistance.',
                        textAlign: TextAlign.center,
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

    // Activated license or active subscription.
    if ((_activated && _deviceAuthorized) || _subscriptionActive) {
      return const LoginScreen();
    }

    // Trial has expired.
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
                        'Your trial period has ended. Please activate '
                        'or renew your subscription to continue using '
                        'the app.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _checkingSubscription
                              ? null
                              : _refreshSubscription,
                          icon: _checkingSubscription
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _checkingSubscription
                                ? 'Checking...'
                                : 'Refresh Subscription',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _openActivation,
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Activate License'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Plans: Monthly / Yearly\n'
                        'Please contact admin after payment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                        ),
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

    // Trial is currently active.
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
                      'Time remaining: '
                      '${LicenseService.formatDuration(_remaining)}',
                      textAlign: TextAlign.center,
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
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed:
                            _checkingSubscription ? null : _refreshSubscription,
                        icon: _checkingSubscription
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                          _checkingSubscription
                              ? 'Checking...'
                              : 'Refresh Subscription',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _openActivation,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Activate License'),
                      ),
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
