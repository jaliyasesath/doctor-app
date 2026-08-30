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

  File? _signatureImage;
  File? _medicalCenterLogo;
  File? _slmcIdFrontImage;
  File? _slmcIdBackImage;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _doctorDeclarationAccepted = false;
  bool _termsAccepted = false;
  String _verificationDocumentType = 'SLMCIdentityCard';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRegistrationConditions();
    });
  }

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
    super.dispose();
  }

  Future<void> _pickSignature() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
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

  Future<void> _pickMedicalCenterLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked != null && mounted) setState(() => _medicalCenterLogo = File(picked.path));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logo could not be selected: $error')));
    }
  }

  Future<void> _showRegistrationConditions() async {
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF0F766E),
            size: 42,
          ),
          title: const Text('Doctor Account Registration'),
          content: const SingleChildScrollView(
            child: Text(
              'This application is intended only for appropriately qualified '
              'and registered medical practitioners.\n\n'
              'You must provide accurate personal and professional details, '
              'a valid SLMC registration number, and clear images of your '
              'verification document.\n\n'
              'Your account will remain pending until an administrator '
              'checks the submitted documents and the SLMC register. False '
              'or altered information may result in rejection or suspension.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('I Understand and Continue'),
            ),
          ],
        );
      },
    );

    if (accepted != true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickVerificationImage({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a clear photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;

      setState(() {
        if (front) {
          _slmcIdFrontImage = File(picked.path);
        } else {
          _slmcIdBackImage = File(picked.path);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document image could not be selected: $error')),
      );
    }
  }

  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    if (_slmcIdFrontImage == null || _slmcIdBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload both the front and back ID images.'),
        ),
      );
      return;
    }

    if (!_doctorDeclarationAccepted || !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Accept the doctor declaration and privacy terms to continue.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    if (ConnectionModeService.getCurrentMode() != 'wifi') {
      // await ConnectionModeService.setLocalWifiMode(); // Local testing.
      await ConnectionModeService.setCloudMode();
    }

    try {
      final result = await _apiAuthService.register(
        doctorName: _doctorNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        specialization: _specializationController.text.trim(),
        medicalCenterName: _medicalCenterNameController.text.trim(),
        role: 'Doctor',
        qualifications: _qualificationsController.text.trim(),
        profession: _professionController.text.trim(),
        slmcRegNo: _slmcRegNoController.text.trim(),
        affiliation: _affiliationController.text.trim(),
        linkedDoctorEmail: '',
        signaturePath: _signatureImage?.path ?? '',
        medicalCenterLogoPath: _medicalCenterLogo?.path ?? '',
        biometricEnabled: 0,
        slmcIdFront: _slmcIdFrontImage!,
        slmcIdBack: _slmcIdBackImage!,
        verificationDocumentType: _verificationDocumentType,
        doctorDeclarationAccepted: _doctorDeclarationAccepted,
        termsAccepted: _termsAccepted,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFF0F766E),
              size: 44,
            ),
            title: const Text('Verification Pending'),
            content: Text(
              result['message']?.toString() ??
                  'Your registration was submitted. You can log in after an '
                      'administrator verifies your SLMC details and ID images.',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        );

        if (!mounted) return;
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
      validator: (value) {
        final requiredError = requiredField ? _required(value, label) : null;
        if (requiredError != null) return requiredError;
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        if (controller == _emailController &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Enter a valid email address';
        }
        if (controller == _contactNumberController &&
            !RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(text)) {
          return 'Enter a valid contact number';
        }
        return null;
      },
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
        if (value.trim().length < 8) {
          return 'Password must be at least 8 characters';
        }
        final strong = RegExp(
          r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$',
        ).hasMatch(value);
        if (!strong) {
          return 'Use upper/lower-case, a number and a special character';
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
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
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

  Widget _medicalCenterLogoPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Medical Centre Logo (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Reused on prescriptions, PDFs and laboratory emails.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        if (_medicalCenterLogo != null) ...[
          const SizedBox(height: 12),
          Center(child: Image.file(_medicalCenterLogo!, height: 100, fit: BoxFit.contain)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _pickMedicalCenterLogo,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_medicalCenterLogo == null ? 'Choose logo' : 'Change logo'),
          )),
          if (_medicalCenterLogo != null)
            IconButton(onPressed: () => setState(() => _medicalCenterLogo = null), icon: const Icon(Icons.delete_outline), color: Colors.red),
        ]),
      ]),
    );
  }

  Widget _verificationDocumentPicker({
    required String title,
    required bool front,
  }) {
    final image = front ? _slmcIdFrontImage : _slmcIdBackImage;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: image == null
              ? const Color(0xFF0F766E).withValues(alpha: 0.20)
              : const Color(0xFF22A06B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                image == null
                    ? Icons.badge_outlined
                    : Icons.check_circle_rounded,
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$title *',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                image,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _pickVerificationImage(front: front),
            icon: Icon(
              image == null ? Icons.add_a_photo_outlined : Icons.refresh,
            ),
            label: Text(image == null ? 'Add Image' : 'Change Image'),
          ),
        ],
      ),
    );
  }

  Widget _verificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE9E5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Identity Verification',
            style: TextStyle(
              color: Color(0xFF14213D),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Your account remains pending until an administrator checks these '
            'documents against the SLMC register.',
            style: TextStyle(color: Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _verificationDocumentType,
            decoration: const InputDecoration(
              labelText: 'Verification Document Type *',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'SLMCIdentityCard',
                child: Text('SLMC Identity Card'),
              ),
              DropdownMenuItem(
                value: 'NationalIdentityCard',
                child: Text('National Identity Card'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _verificationDocumentType = value);
            },
          ),
          const SizedBox(height: 14),
          _verificationDocumentPicker(
            title: 'ID Front Photo',
            front: true,
          ),
          const SizedBox(height: 12),
          _verificationDocumentPicker(
            title: 'ID Back Photo',
            front: false,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _doctorDeclarationAccepted,
            onChanged: (value) {
              setState(() => _doctorDeclarationAccepted = value ?? false);
            },
            title: const Text(
              'I confirm that I am an appropriately qualified and registered '
              'medical practitioner.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _termsAccepted,
            onChanged: (value) {
              setState(() => _termsAccepted = value ?? false);
            },
            title: const Text(
              'I accept the Terms of Use and Privacy Notice and consent to '
              'processing these documents for verification.',
              style: TextStyle(fontSize: 13),
            ),
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
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Doctor'),
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
                    'Create Doctor Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _field(
                    controller: _doctorNameController,
                    label: 'Doctor Name',
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
                  _field(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _medicalCenterNameController,
                    label: 'Medical Centre Name',
                    icon: Icons.local_hospital_outlined,
                  ),
                  const SizedBox(height: 14),
                  _medicalCenterLogoPicker(),
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
                  const SizedBox(height: 18),
                  _verificationSection(),
                  const SizedBox(height: 16),
                  _stampPreview(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ||
                              !_doctorDeclarationAccepted ||
                              !_termsAccepted
                          ? null
                          : _registerDoctor,
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
                            ? 'Submitting...'
                            : 'Submit for Verification',
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
