import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../dashboard/screens/home_screen.dart';
import '../../license/data/license_api_service.dart';
import '../../license/data/license_cache_service.dart';
import '../../net_service/token_storage.dart';
import '../../reception/screens/reception_dashboard_screen.dart';
import '../data/api_auth_service.dart';
import '../data/doctor_session.dart';
import 'doctor_registration_screen.dart';
import '../../../data/local/database_helper.dart';
import '../../net_service/connection_mode_service.dart';
import '../../notifications/services/local_notification_service.dart';
import '../../followup/screens/follow_up_screen.dart';
import '../../sync/services/sync_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final ApiAuthService _apiAuthService = ApiAuthService();
  final LicenseApiService _licenseApiService = LicenseApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricEnabledForLastDoctor = false;
  bool _deviceSupportsBiometric = false;
  String _lastDoctorName = '';

  @override
void initState() {
  super.initState();

  _loadBiometricState().then((_) async {
    if (!mounted) return;

    if (_biometricEnabledForLastDoctor &&
        _deviceSupportsBiometric &&
        _lastDoctorName.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _loginWithBiometric();
    }
  });
}

  Future<void> _loadBiometricState() async {
    final lastDoctor = await DoctorSession.getLastDoctorForBiometric();

    bool supported = false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      supported = canCheck || isSupported;
    } catch (_) {
      supported = false;
    }

    if (!mounted) return;

    setState(() {
      _deviceSupportsBiometric = supported;
      _lastDoctorName = lastDoctor?['doctor_name']?.toString() ?? '';
      _biometricEnabledForLastDoctor =
          (lastDoctor?['biometric_enabled'] ?? 0) == 1;
    });
  }

  

  Future<void> _navigateByRole(String role) async {
  final shouldOpenFollowUps =
      await LocalNotificationService
          .consumePendingFollowUpOpen();

  if (!mounted) return;

  if (shouldOpenFollowUps) {
  final targetId =
      await LocalNotificationService
          .consumePendingFollowUpId();

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => FollowUpScreen(
        targetPrescriptionId: targetId,
      ),
    ),
  );
  return;
}

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) =>
          role.toLowerCase() == 'reception'
              ? const ReceptionDashboardScreen()
              : const HomeScreen(),
    ),
  );
}


  Future<bool> _checkOnlineLicense() async {
    final licenseResult = await _licenseApiService.getStatus();

    if (!mounted) return false;

    if (licenseResult['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(licenseResult['message'] ?? 'License check failed'),
        ),
      );
      return false;
    }

    final licenseData = Map<String, dynamic>.from(
      licenseResult['data'] as Map,
    );

    final mode = licenseResult['mode']?.toString() ?? 'online';

    final isActive = licenseData['isActive'] == true;
    final isExpired = licenseData['isExpired'] == true;
    final planName = licenseData['planName']?.toString() ?? '';
    final daysRemaining = licenseData['daysRemaining']?.toString() ?? '0';

    if (!isActive || isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('License expired. Please renew subscription.'),
        ),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == 'online'
              ? '$planName active - $daysRemaining days remaining'
              : 'Offline license valid ✅ $daysRemaining days remaining',
        ),
      ),
    );

    return true;
  }

  Future<bool> _checkOfflineLicenseOnly() async {
    final valid = await LicenseCacheService.isLicenseValidOffline();

    if (!mounted) return false;

    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid offline license. Connect internet once.'),
        ),
      );
      return false;
    }

    final data = await LicenseCacheService.getCachedLicense();
    final days = data['daysRemaining']?.toString() ?? '0';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offline license valid ✅ $days days remaining'),
      ),
    );

    return true;
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    await ConnectionModeService.setCloudMode();

    try {
      final result = await _apiAuthService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Invalid email or password'),
          ),
        );
        return;
      }

      final doctor = result['doctor'] as Map<String, dynamic>;
      final mode = result['mode']?.toString() ?? 'online';

      if (mode == 'online') {
        final savedToken = await TokenStorage.getToken();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedToken == null || savedToken.isEmpty
                  ? 'Token NOT saved'
                  : 'Token saved OK',
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 400));

        final licenseOk = await _checkOnlineLicense();
        if (!licenseOk) return;
      } else {
        final licenseOk = await _checkOfflineLicenseOnly();
        if (!licenseOk) return;

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline login success ✅')),
        );
      }

      await DoctorSession.enableBiometric();

final doctorId = await DoctorSession.getDoctorId();

if (doctorId != null) {
  await DatabaseHelper.instance.updateDoctor(
    doctorId,
    {
      'biometric_enabled': 1,
    },
  );
}

await SyncService().resetSyncTimestamps();
await SyncService().syncAll();

      if (!mounted) return;

      final displayName =
          doctor['doctorName'] ?? doctor['doctor_name'] ?? 'Doctor';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome $displayName')),
      );

      final role =
          doctor['role']?.toString() ?? doctor['Role']?.toString() ?? 'Doctor';

      _navigateByRole(role);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    try {
      final lastDoctor = await DoctorSession.getLastDoctorForBiometric();

      if (lastDoctor == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No doctor available for biometric login'),
          ),
        );
        return;
      }

      final biometricEnabled = (lastDoctor['biometric_enabled'] ?? 0) == 1;

      if (!biometricEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login is not enabled')),
        );
        return;
      }

      final isSupported = await _localAuth.isDeviceSupported();

      if (!isSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device authentication is not available'),
          ),
        );
        return;
      }

     final authenticated = await _localAuth.authenticate(
  localizedReason: 'Use Face ID to login to Doctor App',
  biometricOnly: false,
  persistAcrossBackgrounding: true,
);

      if (!authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
        return;
      }

      final licenseOk = await _checkOfflineLicenseOnly();
      if (!licenseOk) return;

      await DoctorSession.saveDoctorSession({
        'id': (lastDoctor['id'] is int)
            ? lastDoctor['id']
            : int.tryParse(lastDoctor['id'].toString()) ?? 0,
        'doctor_name': lastDoctor['doctor_name'] ?? '',
        'email': lastDoctor['email'] ?? '',
        'password': lastDoctor['password'] ?? '',
        'role': lastDoctor['role'] ?? 'Doctor',
        'medical_center_name': lastDoctor['medical_center_name'] ?? '',
        'specialization': lastDoctor['specialization'] ?? '',
        'clinic_address': lastDoctor['clinic_address'] ?? '',
        'biometric_enabled': 1,
      });

      try {
  final email = lastDoctor['email']?.toString() ?? '';
  final password = lastDoctor['password']?.toString() ?? '';

  if (email.isNotEmpty && password.isNotEmpty) {
    await _apiAuthService.login(
      email: email,
      password: password,
    );
  }
} catch (_) {
  // Ignore. Biometric login can still continue offline.
}

      final doctorId = await DoctorSession.getDoctorId();

      if (doctorId != null && doctorId > 0) {
        await DatabaseHelper.instance.assignOldLocalDataToDoctor(doctorId);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome ${lastDoctor['doctor_name'] ?? 'Doctor'}'),
        ),
      );

      final role = lastDoctor['role']?.toString() ?? 'Doctor';
      _navigateByRole(role);
    } on LocalAuthException catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Authentication failed: ${e.toString()}'),
    ),
  );
} catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Biometric login error: $e')),
  );
}
  }

  void _openRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DoctorRegistrationScreen(),
      ),
    ).then((_) => _loadBiometricState());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBiometricButton =
        _biometricEnabledForLastDoctor &&
        _deviceSupportsBiometric &&
        _lastDoctorName.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_hospital,
                        size: 60,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Doctor App',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (showBiometricButton)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loginWithBiometric,
                            icon: const Icon(Icons.fingerprint),
                            label: Text(
                              'Login with Biometric'
                              '${_lastDoctorName.isNotEmpty ? ' ($_lastDoctorName)' : ''}',
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _openRegistration,
                        child: const Text('Register New Doctor'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}