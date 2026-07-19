import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api_auth_service.dart';
import 'login_screen.dart';
import '../../net_service/connection_mode_service.dart';


class DoctorRegistrationScreen extends StatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  State<DoctorRegistrationScreen> createState() =>
      _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiAuthService _apiAuthService = ApiAuthService();

  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _medicalCenterNameController =
      TextEditingController();

  final TextEditingController _qualificationsController =
      TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _slmcRegNoController = TextEditingController();
  final TextEditingController _affiliationController = TextEditingController();
  final TextEditingController _linkedDoctorEmailController =
      TextEditingController();

  File? _signatureImage;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricEnabled = false;
  String _selectedRole = 'Doctor';

  @override
  void dispose() {
    _doctorNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactNumberController.dispose();
    _specializationController.dispose();
    _medicalCenterNameController.dispose();
    _qualificationsController.dispose();
    _professionController.dispose();
    _slmcRegNoController.dispose();
    _affiliationController.dispose();
    _linkedDoctorEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickSignature() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null) return;

      setState(() {
        _signatureImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signature pick failed: $e')),
      );
    }
  }

  Future<void> _removeSignature() async {
    setState(() {
      _signatureImage = null;
    });
  }

  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await ConnectionModeService.setCloudMode();

    try {
      final result = await _apiAuthService.register(
        doctorName: _doctorNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        specialization: _specializationController.text.trim(),
        medicalCenterName: _medicalCenterNameController.text.trim(),
        role: _selectedRole,
        qualifications: _qualificationsController.text.trim(),
        profession: _professionController.text.trim(),
        slmcRegNo: _slmcRegNoController.text.trim(),
        affiliation: _affiliationController.text.trim(),
        linkedDoctorEmail: _linkedDoctorEmailController.text.trim(),
        signaturePath: _signatureImage?.path ?? '',
        biometricEnabled: _biometricEnabled ? 1 : 0,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final mode = result['mode']?.toString() ?? '';

        final roleText = _selectedRole == 'Reception'
            ? 'Reception'
            : 'Doctor';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mode == 'offline'
                  ? '$roleText registered offline ✅'
                  : '$roleText registered online ✅',
            ),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registration failed'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e')),
      );
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool requiredField = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: requiredField ? (v) => _required(v, label) : null,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Password is required';
        }
        if (value.trim().length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Password *',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _signaturePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Doctor Signature (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload PNG/JPG signature image. You can skip this.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_signatureImage != null)
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Image.file(
                  _signatureImage!,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (_signatureImage != null) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSignature,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _signatureImage == null
                        ? 'Upload Signature'
                        : 'Change Signature',
                  ),
                ),
              ),
              if (_signatureImage != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _removeSignature,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stampPreview() {
    final name = _doctorNameController.text.trim();
    final qualifications = _qualificationsController.text.trim();
    final profession = _professionController.text.trim();
    final slmc = _slmcRegNoController.text.trim();
    final affiliation = _affiliationController.text.trim();
    final contact = _contactNumberController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Doctor Stamp Preview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          if (_signatureImage != null)
            Center(
              child: Image.file(
                _signatureImage!,
                height: 70,
                fit: BoxFit.contain,
              ),
            ),
          if (_signatureImage != null) const SizedBox(height: 8),
          Text(
            name.isEmpty ? 'Dr. Doctor Name' : 'Dr. $name',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (qualifications.isNotEmpty) Text(qualifications),
          const SizedBox(height: 10),
          if (profession.isNotEmpty) Text(profession),
          const SizedBox(height: 10),
          if (slmc.isNotEmpty) Text('SLMC Reg. No: $slmc'),
          const SizedBox(height: 10),
          if (affiliation.isNotEmpty) Text(affiliation),
          if (contact.isNotEmpty) Text('Tel: $contact'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReception = _selectedRole == 'Reception';

    return Scaffold(
      appBar: AppBar(
        title: Text(isReception ? 'Register Reception' : 'Register Doctor'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.local_hospital,
                    size: 60,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isReception
                        ? 'Create Reception Account'
                        : 'Create Doctor Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _field(
                    controller: _doctorNameController,
                    label: isReception ? 'Reception Name' : 'Doctor Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _passwordField(),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Account Role',
                      prefixIcon:
                          const Icon(Icons.admin_panel_settings_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Doctor',
                        child: Text('Doctor'),
                      ),
                      DropdownMenuItem(
                        value: 'Reception',
                        child: Text('Reception'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (isReception) ...[
                    _field(
                      controller: _linkedDoctorEmailController,
                      label: 'Linked Doctor Email',
                      icon: Icons.local_hospital_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  if (!isReception) ...[
                    _field(
                      controller: _medicalCenterNameController,
                      label: 'Channeling Center Name',
                      icon: Icons.local_hospital_outlined,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _specializationController,
                      label: 'Specialization',
                      icon: Icons.medical_information_outlined,
                      requiredField: false,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Doctor Stamp Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _qualificationsController,
                      label: 'Qualifications',
                      icon: Icons.school_outlined,
                      requiredField: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _professionController,
                      label: 'Profession / Specialty',
                      icon: Icons.badge_outlined,
                      requiredField: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _slmcRegNoController,
                      label: 'SLMC Registration Number',
                      icon: Icons.confirmation_number_outlined,
                      requiredField: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _affiliationController,
                      label: 'Affiliation / Hospital / Clinic',
                      icon: Icons.apartment_outlined,
                      requiredField: false,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _signaturePicker(),
                    const SizedBox(height: 16),
                  ],
                  SwitchListTile(
                    value: _biometricEnabled,
                    onChanged: (value) {
                      setState(() => _biometricEnabled = value);
                    },
                    title: const Text('Enable Biometric Login'),
                    subtitle: const Text('Fingerprint / Face / PIN fallback'),
                    secondary: const Icon(Icons.fingerprint),
                  ),
                  if (!isReception) ...[
                    const SizedBox(height: 14),
                    _stampPreview(),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _registerDoctor,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.app_registration),
                      label: Text(
                        _isLoading
                            ? 'Registering...'
                            : isReception
                                ? 'Register Reception'
                                : 'Register Doctor',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

