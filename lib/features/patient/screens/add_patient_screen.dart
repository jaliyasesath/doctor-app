import 'package:flutter/material.dart';

import '../../../core/widgets/app_error_ui.dart';
import '../data/api_patient_service.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicController = TextEditingController();
  final _alertsController = TextEditingController();

  final ApiPatientService _api = ApiPatientService();

  String _gender = 'Male';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _allergiesController.dispose();
    _chronicController.dispose();
    _alertsController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final result = await _api.addPatient(
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _gender,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        notes: '',
        allergies: _allergiesController.text.trim(),
        chronicDiseases: _chronicController.text.trim(),
        importantAlerts: _alertsController.text.trim(),
      );

      if (!mounted) return;

      final patientCode = result['patientCode']?.toString() ?? '';
      final offline = result['offline'] == true;
      final queueNo = result['queueNo']?.toString() ?? '';

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            offline ? 'Patient Saved Offline' : 'Patient Registered',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Patient ID: ${patientCode.isEmpty ? '-' : patientCode}'),
              const SizedBox(height: 8),
              Text('Queue No: ${queueNo.isEmpty ? '-' : queueNo}'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _nameController.clear();
      _ageController.clear();
      _phoneController.clear();
      _addressController.clear();

      _allergiesController.clear();
      _chronicController.clear();
      _alertsController.clear();

      setState(() => _gender = 'Male');
    } catch (e) {
      if (!mounted) return;

      AppErrorUi.show(
        context,
        e,
        onRetry: _savePatient,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Register Patient'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 54,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Reception Patient Registration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _field(
                      controller: _nameController,
                      label: 'Patient Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender *',
                        prefixIcon: const Icon(Icons.wc_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      requiredField: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _addressController,
                      label: 'Address',
                      icon: Icons.location_on_outlined,
                      requiredField: false,
                      maxLines: 2,
                    ),
                    _field(
                      controller: _allergiesController,
                      label: 'Allergies',
                      icon: Icons.warning_amber_rounded,
                      requiredField: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _chronicController,
                      label: 'Chronic Diseases',
                      icon: Icons.monitor_heart_outlined,
                      requiredField: false,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _alertsController,
                      label: 'Important Alerts',
                      icon: Icons.notification_important_outlined,
                      requiredField: false,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _savePatient,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Patient'),
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
