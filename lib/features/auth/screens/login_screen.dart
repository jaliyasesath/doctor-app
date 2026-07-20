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
  localizedReason: 'Use device authentication to access PP Private Practice',
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
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF063B91),
                          Color(0xFF075EA8),
                          Color(0xFF0A969B),
                        ],
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 6,
                  child: ColoredBox(color: Color(0xFFF1F5F9)),
                ),
              ],
            ),
          ),
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 125,
            left: -65,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 46,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 154,
                              height: 154,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.72),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x3300206A),
                                    blurRadius: 28,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(27),
                                child: Image.asset(
                                  'assets/images/private_practices_logo.jpeg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const ColoredBox(
                                      color: Colors.white,
                                      child: Center(
                                        child: Icon(
                                          Icons.local_hospital_rounded,
                                          color: Color(0xFF075EA8),
                                          size: 68,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Private Practices',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Care starts with a tap.',
                              style: TextStyle(
                                color: Color(0xFFD5FAF7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A0F172A),
                                    blurRadius: 35,
                                    offset: Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: AutofillGroup(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Welcome back',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Sign in to manage your private practice.',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Email address',
                                      style: TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _emailController,
                                      enabled: !_isLoading,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.email],
                                      decoration: InputDecoration(
                                        hintText: 'doctor@clinic.com',
                                        prefixIcon: const Icon(
                                          Icons.mail_outline_rounded,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF0F766E),
                                            width: 1.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 17),
                                    const Text(
                                      'Password',
                                      style: TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _passwordController,
                                      enabled: !_isLoading,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [AutofillHints.password],
                                      onSubmitted: (_) {
                                        if (!_isLoading) _login();
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Enter your password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF0F766E),
                                            width: 1.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor:
                                              const Color(0xFF0F766E),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              const Color(0xFF99F6E4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        onPressed: _isLoading ? null : _login,
                                        child: _isLoading
                                            ? const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.3,
                                                      color: Color(0xFF0F766E),
                                                    ),
                                                  ),
                                                  SizedBox(width: 11),
                                                  Text('Signing in...'),
                                                ],
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Sign in securely',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(width: 9),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    if (showBiometricButton) ...[
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFF0F766E),
                                            side: const BorderSide(
                                              color: Color(0xFF99F6E4),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                          ),
                                          onPressed: _isLoading
                                              ? null
                                              : _loginWithBiometric,
                                          icon: const Icon(Icons.fingerprint),
                                          label: Text(
                                            'Continue as $_lastDoctorName',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    const Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'New to PP?',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton.icon(
                                        onPressed:
                                            _isLoading ? null : _openRegistration,
                                        icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 19,
                                        ),
                                        label: const Text(
                                          'Create a practitioner account',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF0F766E),
                                    size: 17,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Secure access • Cloud sync • Offline ready',
                                    style: TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
