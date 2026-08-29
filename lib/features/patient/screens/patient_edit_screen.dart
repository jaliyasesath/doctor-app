import 'package:flutter/material.dart';
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
}
