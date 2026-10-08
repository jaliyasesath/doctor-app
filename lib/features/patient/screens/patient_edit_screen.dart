import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/desktop_module_shell.dart';
import '../../../data/local/database_helper.dart';
import '../../sync/services/network_service.dart';
import '../../sync/services/sync_service.dart';

class PatientEditScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientEditScreen({
    super.key,
    required this.patient,
  });

  @override
  State<PatientEditScreen> createState() => _PatientEditScreenState();
}

class _PatientEditScreenState extends State<PatientEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  late final TextEditingController _allergiesController;
  late final TextEditingController _chronicController;
  late final TextEditingController _alertsController;

  late String _selectedGender;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: (widget.patient['patientName'] ??
              widget.patient['patient_name'] ??
              '')
          .toString(),
    );

    _ageController = TextEditingController(
      text: (widget.patient['patientAge'] ??
              widget.patient['age'] ??
              widget.patient['patient_age'] ??
              '')
          .toString(),
    );

    _phoneController = TextEditingController(
      text: (widget.patient['phoneNumber'] ??
              widget.patient['phone_number'] ??
              '')
          .toString(),
    );

    _addressController = TextEditingController(
      text: (widget.patient['address'] ?? '').toString(),
    );

    _notesController = TextEditingController(
      text: (widget.patient['notes'] ?? '').toString(),
    );

    _allergiesController = TextEditingController(
      text: (widget.patient['allergies'] ?? '').toString(),
    );

    _chronicController = TextEditingController(
      text: (widget.patient['chronic_diseases'] ??
              widget.patient['chronicDiseases'] ??
              '')
          .toString(),
    );

    _alertsController = TextEditingController(
      text: (widget.patient['important_alerts'] ??
              widget.patient['importantAlerts'] ??
              '')
          .toString(),
    );

    _selectedGender = (widget.patient['patientGender'] ??
            widget.patient['gender'] ??
            widget.patient['patient_gender'] ??
            'Male')
        .toString();

    if (!['Male', 'Female', 'Other'].contains(_selectedGender)) {
      _selectedGender = 'Male';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _allergiesController.dispose();
    _chronicController.dispose();
    _alertsController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final localId = widget.patient['id'] as int;

      await DatabaseHelper.instance.updatePatient(localId, {
        'patient_name': _nameController.text.trim(),
        'patient_age': _ageController.text.trim(),
        'patient_gender': _selectedGender,
        'phone_number': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'notes': _notesController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'chronic_diseases': _chronicController.text.trim(),
        'important_alerts': _alertsController.text.trim(),
      });

      final online = await NetworkService.isOnline();

      if (online) {
        final result = await SyncService().syncAll();

        if (result.hasFailures) {
          throw Exception(
            'Sync failed. Patients failed: ${result.patientFailed}, Rx failed: ${result.prescriptionFailed}',
          );
        }
      }

      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            online
                ? 'Patient saved and synced ✅'
                : 'Saved locally (pending sync)',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000) {
      return _buildDesktop(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Patient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _decoration('Patient Name *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter patient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: _decoration('Age *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter age';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _decoration('Gender *'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedGender = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Phone Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: _decoration('Address'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _decoration('Notes'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergiesController,
                decoration: _decoration('Allergies'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _chronicController,
                decoration: _decoration('Chronic Diseases'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alertsController,
                maxLines: 2,
                decoration: _decoration('Important Alerts'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePatient,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    Widget field({
      required TextEditingController controller,
      required String label,
      TextInputType? keyboardType,
      int maxLines = 1,
      String? Function(String?)? validator,
    }) {
      return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: _decoration(label),
      );
    }

    return DesktopModuleShell(
      title: 'Edit Patient',
      subtitle: 'Update demographics, contact details and clinical alerts',
      icon: Icons.manage_accounts_rounded,
      embedded: true,
      onBack: () => Navigator.pop(context),
      actions: [
        OutlinedButton.icon(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancel'),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DesktopPanel(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DesktopSectionTitle(
                          icon: Icons.badge_outlined,
                          title: 'Personal information',
                          subtitle: 'Core patient identity and contact details',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: field(
                                controller: _nameController,
                                label: 'Patient Name *',
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Enter patient name'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: field(
                                controller: _ageController,
                                label: 'Age *',
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Enter age'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: _decoration('Gender *'),
                                items: const [
                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                ],
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() => _selectedGender = value);
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: field(
                                controller: _phoneController,
                                label: 'Phone Number',
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: field(
                                controller: _addressController,
                                label: 'Address',
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DesktopPanel(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DesktopSectionTitle(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Clinical information',
                          subtitle: 'Important information shown during consultations',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: field(
                                controller: _allergiesController,
                                label: 'Allergies',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: field(
                                controller: _chronicController,
                                label: 'Chronic Diseases',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: field(
                                controller: _alertsController,
                                label: 'Important Alerts',
                                maxLines: 3,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: field(
                                controller: _notesController,
                                label: 'Notes',
                                maxLines: 3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 220,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _savePatient,
                        style: FilledButton.styleFrom(
                          backgroundColor: DesktopModuleShell.teal,
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
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

class _DesktopSectionTitle extends StatelessWidget {
  const _DesktopSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F5F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: DesktopModuleShell.teal),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: DesktopModuleShell.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: DesktopModuleShell.muted)),
          ],
        ),
      ],
    );
  }
}
