import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../prescription/data/prescription_store.dart';
import '../../prescription/models/prescription_item.dart';
import '../../prescription/screens/prescription_list_screen.dart';
import '../../prescription/screens/print_preview_screen.dart';
import '../../template/data/template_service.dart';
import '../../template/models/template_model.dart';
import '../../template/screens/template_list_screen.dart';
import '../../sync/services/auto_sync_service.dart';

class OPDFastModeScreen extends StatefulWidget {
  const OPDFastModeScreen({super.key});

  @override
  State<OPDFastModeScreen> createState() => _OPDFastModeScreenState();
}

class _OPDFastModeScreenState extends State<OPDFastModeScreen> {
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();

  String _selectedGender = 'Male';

  bool _isLoading = true;
  bool _isSaving = false;

  int? _doctorId;
  int? _selectedPatientId;
  String? _selectedTemplateName;

  List<TemplateModel> _favoriteTemplates = [];
  List<TemplateModel> _allTemplates = [];
  List<Map<String, dynamic>> _recentPatients = [];
  List<Map<String, dynamic>> _searchedPatients = [];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final doctorId = await DoctorSession.getDoctorId();

    if (!mounted) return;

    if (doctorId == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor session not found. Login again.')),
      );
      return;
    }

    _doctorId = doctorId;

    await DatabaseHelper.instance.assignOldLocalDataToDoctor(doctorId);
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_doctorId == null) return;

    final favorites = await TemplateService.getFavoriteTemplates();
    final allTemplates = await TemplateService.getTemplates();

    final allPatients =
        await DatabaseHelper.instance.getPatientsByDoctor(_doctorId!);

    if (!mounted) return;

    setState(() {
      _favoriteTemplates = favorites;
      _allTemplates = allTemplates;
      _recentPatients = allPatients.take(5).toList();
      _searchedPatients = [];
      _isLoading = false;
    });
  }

  Future<void> _searchPatients(String query) async {
    if (_doctorId == null) return;

    if (query.trim().isEmpty) {
      setState(() {
        _searchedPatients = [];
      });
      return;
    }

    final result = await DatabaseHelper.instance.searchPatientsByDoctor(
      _doctorId!,
      query.trim(),
    );

    if (!mounted) return;

    setState(() {
      _searchedPatients = result;
    });
  }

  void _pickSavedPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatientId = patient['id'] as int?;
      _patientNameController.text = patient['patient_name']?.toString() ?? '';
      _patientAgeController.text = patient['patient_age']?.toString() ?? '';
      _selectedGender = patient['patient_gender']?.toString() ?? 'Male';
      _patientSearchController.text = patient['patient_name']?.toString() ?? '';
      _searchedPatients = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected patient: ${patient['patient_name'] ?? ''}'),
      ),
    );
  }

  void _applyTemplate(TemplateModel template) {
    final items = TemplateService.decodeItems(template.itemsJson);

    PrescriptionStore.setPatientDetails(
      name: _patientNameController.text.trim(),
      age: _patientAgeController.text.trim(),
      gender: _selectedGender,
    );

    PrescriptionStore.setClinicalDetails(
      complaintText: template.complaint,
      diagnosisText: template.diagnosis,
      visitNotesText: '',
    );

    PrescriptionStore.setItems(
      items.map((e) {
        return PrescriptionItem(
          medicineName: e['name']?.toString() ?? '',
          dosage: e['dosage']?.toString() ?? '',
          frequency: e['frequency']?.toString() ?? '',
          duration: e['duration']?.toString() ?? '',
          instructions: e['instructions']?.toString() ?? '',
        );
      }).toList(),
    );

    setState(() {
      _selectedTemplateName = template.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${template.name} loaded')),
    );
  }

  void _openAllTemplates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplateListScreen(),
      ),
    ).then((_) {
      if (!mounted) return;

      setState(() {
        _selectedTemplateName =
            PrescriptionStore.items.isNotEmpty ? 'Loaded from template' : null;
      });
    });
  }

  List<TemplateModel> _getSmartSuggestedTemplates() {
    final query = _patientSearchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _allTemplates.take(6).toList();
    }

    final filtered = _allTemplates.where((t) {
      return t.name.toLowerCase().contains(query) ||
          t.complaint.toLowerCase().contains(query) ||
          t.diagnosis.toLowerCase().contains(query);
    }).toList();

    return filtered.take(6).toList();
  }

  Future<int?> _saveOrUpdatePatientMaster() async {
    if (_doctorId == null) return null;

    final name = _patientNameController.text.trim();
    final age = _patientAgeController.text.trim();
    final gender = _selectedGender;

    if (name.isEmpty || age.isEmpty) return null;

    if (_selectedPatientId != null) {
      return _selectedPatientId;
    }

    final patientData = {
      'doctor_id': _doctorId,
      'patient_name': name,
      'patient_age': age,
      'patient_gender': gender,
      'phone_number': null,
      'address': null,
      'notes': null,
      'created_at': DateTime.now().toIso8601String(),
    };

    final matches =
        await DatabaseHelper.instance.getPatientsByBasicDetailsWithoutPhone(
      patientName: name,
      patientAge: age,
      patientGender: gender,
    );

    final doctorMatches = matches.where((p) {
      return p['doctor_id'] == _doctorId;
    }).toList();

    if (doctorMatches.isNotEmpty) {
      return doctorMatches.first['id'] as int;
    }

    return DatabaseHelper.instance.insertPatient(patientData);
  }

  Future<void> _showAfterSaveDialog({
    required String rxNo,
    required String savedDate,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Prescription Saved'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prescription saved successfully.'),
              const SizedBox(height: 8),
              Text(
                'RX: $rxNo',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrintPreviewScreen(
                      passedRxNo: rxNo,
                      passedDate: savedDate,
                    ),
                  ),
                );
              },
              child: const Text('Preview'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrintPreviewScreen(
                      passedRxNo: rxNo,
                      passedDate: savedDate,
                    ),
                  ),
                );
              },
              child: const Text('Print Now'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _quickSave() async {
    if (_isSaving) return;
    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor session not found. Login again.')),
      );
      return;
    }

    if (_patientNameController.text.trim().isEmpty ||
        _patientAgeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter patient name and age')),
      );
      return;
    }

    if (PrescriptionStore.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a template first')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final patientId = await _saveOrUpdatePatientMaster();

      if (patientId == null) {
        throw Exception('Patient save failed');
      }

      final rxNo = await PrescriptionStore.generatePersistentRxNumber();
      final savedDate = DateTime.now().toString().substring(0, 10);

      PrescriptionStore.setPatientDetails(
        name: _patientNameController.text.trim(),
        age: _patientAgeController.text.trim(),
        gender: _selectedGender,
      );

      final itemsText = PrescriptionStore.items.map((item) {
        return '${item.medicineName} | ${item.dosage} | ${item.frequency} | ${item.duration} | ${item.instructions}';
      }).join('\n');

      final data = {
        'doctor_id': _doctorId,
        'patient_id': patientId,
        'patient_name': PrescriptionStore.patientName,
        'patient_age': PrescriptionStore.patientAge,
        'patient_gender': PrescriptionStore.patientGender,
        'prescription_no': rxNo,
        'prescription_date': savedDate,
        'items_text': itemsText,
        'complaint': PrescriptionStore.complaint.isEmpty
            ? null
            : PrescriptionStore.complaint,
        'diagnosis': PrescriptionStore.diagnosis.isEmpty
            ? null
            : PrescriptionStore.diagnosis,
        'visit_notes': PrescriptionStore.visitNotes.isEmpty
            ? null
            : PrescriptionStore.visitNotes,
        'server_patient_id': null,
      };

      await DatabaseHelper.instance.insertPrescription(data);
      unawaited(AutoSyncService.syncPendingChanges());

      if (!mounted) return;

      await _showAfterSaveDialog(
        rxNo: rxNo,
        savedDate: savedDate,
      );

      setState(() {
        _selectedTemplateName = null;
        _selectedPatientId = null;
        _patientSearchController.clear();
        _patientNameController.clear();
        _patientAgeController.clear();
        _selectedGender = 'Male';
        _searchedPatients = [];
      });

      PrescriptionStore.clear();
      await _loadInitialData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quick save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _continueToPrescription() {
    if (_patientNameController.text.trim().isEmpty ||
        _patientAgeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter patient name and age')),
      );
      return;
    }

    if (PrescriptionStore.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a template first')),
      );
      return;
    }

    PrescriptionStore.setPatientDetails(
      name: _patientNameController.text.trim(),
      age: _patientAgeController.text.trim(),
      gender: _selectedGender,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrescriptionListScreen(),
      ),
    );
  }

  void _clearLoadedData() {
    setState(() {
      _selectedTemplateName = null;
    });

    PrescriptionStore.items.clear();
    PrescriptionStore.setClinicalDetails(
      complaintText: '',
      diagnosisText: '',
      visitNotesText: '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loaded template cleared')),
    );
  }

  Widget _buildSavedPatientSearch() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _patientSearchController,
            decoration: InputDecoration(
              labelText: 'Search saved patients',
              hintText: 'Name or phone',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _searchPatients,
          ),
          if (_searchedPatients.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _searchedPatients.length,
                itemBuilder: (context, index) {
                  final patient = _searchedPatients[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(patient['patient_name']?.toString() ?? ''),
                    subtitle: Text(
                      'Age: ${patient['patient_age'] ?? ''} | ${patient['patient_gender'] ?? ''}',
                    ),
                    onTap: () => _pickSavedPatient(patient),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentPatients() {
    if (_recentPatients.isEmpty) {
      return const Text(
        'No recent patients',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recentPatients.map((patient) {
        return ActionChip(
          avatar: const Icon(Icons.history, size: 18),
          label: Text(patient['patient_name']?.toString() ?? ''),
          onPressed: () => _pickSavedPatient(patient),
        );
      }).toList(),
    );
  }

  Widget _buildQuickTemplateButtons() {
    if (_favoriteTemplates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No favorite templates found. Mark templates as favorite first.',
          style: TextStyle(color: Colors.black87),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _favoriteTemplates.map((template) {
        return ActionChip(
          avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
          label: Text(template.name),
          onPressed: () => _applyTemplate(template),
        );
      }).toList(),
    );
  }

  Widget _buildSmartSuggestions() {
    final suggestions = _getSmartSuggestedTemplates();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((template) {
        return ActionChip(
          avatar: const Icon(Icons.auto_awesome, size: 18),
          label: Text(template.name),
          onPressed: () => _applyTemplate(template),
        );
      }).toList(),
    );
  }

  Widget _buildLoadedMedicines() {
    final items = PrescriptionStore.items;

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No template loaded yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedTemplateName ?? 'Loaded Template',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearLoadedData,
                child: const Text('Clear'),
              ),
            ],
          ),
          if (PrescriptionStore.complaint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Complaint: ${PrescriptionStore.complaint}'),
            ),
          ],
          if (PrescriptionStore.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Diagnosis: ${PrescriptionStore.diagnosis}'),
            ),
          ],
          const SizedBox(height: 12),
          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.medicineName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.dosage} • ${item.frequency} • ${item.duration}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OPD Ultra Fast Mode'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSavedPatientSearch(),
                const SizedBox(height: 16),
                const Text(
                  '🕒 Recent Patients',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildRecentPatients(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _patientNameController,
                        decoration: _input('Patient Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _patientAgeController,
                        keyboardType: TextInputType.number,
                        decoration: _input('Patient Age'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: _input('Gender'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '⭐ Favorite Templates',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildQuickTemplateButtons(),
                const SizedBox(height: 18),
                const Text(
                  '🤖 Smart Suggestions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildSmartSuggestions(),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _openAllTemplates,
                  icon: const Icon(Icons.folder_copy_outlined),
                  label: const Text('All Templates'),
                ),
                const SizedBox(height: 18),
                const Text(
                  '🩺 Loaded Prescription Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildLoadedMedicines(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _quickSave,
                          icon: const Icon(Icons.bolt),
                          label: Text(_isSaving ? 'Saving...' : 'Quick Save'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _continueToPrescription,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Manual Review'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
