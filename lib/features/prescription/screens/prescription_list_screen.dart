import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../patient/data/api_patient_service.dart';
import '../../auth/data/doctor_session.dart';
import '../../sync/services/network_service.dart';
import '../../sync/services/auto_sync_service.dart';
import '../../sync/services/sync_service.dart';
import '../../template/data/template_service.dart';
import '../../template/models/template_model.dart';
import '../../template/screens/template_list_screen.dart';
import '../data/prescription_store.dart';
import '../models/prescription_item.dart';
import '../widgets/smart_chips_section.dart';
import 'print_preview_screen.dart';
import '../../notifications/services/local_notification_service.dart';
import '../../lab/screens/create_lab_order_screen.dart';

class PrescriptionListScreen extends StatefulWidget {
  final bool isEditMode;
  final int? editingPrescriptionId;
  final String? existingRxNo;
  final String? existingDate;
  final int? existingPatientId;

  final String? patientName;
  final String? patientAge;
  final String? patientGender;
  final String? patientPhone;
  final String? patientAddress;

  const PrescriptionListScreen({
    super.key,
    this.isEditMode = false,
    this.editingPrescriptionId,
    this.existingRxNo,
    this.existingDate,
    this.existingPatientId,
    this.patientName,
    this.patientAge,
    this.patientGender,
    this.patientPhone,
    this.patientAddress,
  });

  @override
  State<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends State<PrescriptionListScreen> {
  late final TextEditingController _patientNameController;
  late final TextEditingController _patientAgeController;
  late final TextEditingController _patientPhoneController;
  late final TextEditingController _patientAddressController;
  late final TextEditingController _patientNotesController;

  late final TextEditingController _complaintController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _complaintSearchController;
  late final TextEditingController _diagnosisSearchController;
  late final TextEditingController _visitNotesController;

  late final TextEditingController _bloodPressureController;
  late final TextEditingController _weightController;
  late final TextEditingController _pulseController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _spo2Controller;

  late final TextEditingController _followUpNoteController;
  late final TextEditingController _consultationFeeController;

  DateTime? _followUpDate;

  bool _enableAppReminder = true;
  bool _enableWhatsappReminder = false;
  bool _enableSmsReminder = false;

  String _selectedGender = 'Male';
  String? _currentRxNo;
  int? _currentPatientId;
  int? _currentPrescriptionId;
  bool _prescriptionSaved = false;
  final ApiPatientService _patientApi = ApiPatientService();

  final List<String> _selectedComplaintChips = [];
  final List<String> _selectedDiagnosisChips = [];

  List<String> selectedAllergies = [];
  List<String> selectedDiseases = [];

  List<Map<String, dynamic>> masterMedicines = [];
  Map<String, dynamic>? selectedMedicine;
  int? loggedDoctorId;

  List<Map<String, dynamic>> customInstructions = [];
  List<TemplateModel> _favoriteTemplates = [];

  final Map<String, String> defaultInstructions = {
    'Tablet': 'After meals',
    'Capsule': 'After meals',
    'Syrup': 'Shake well before use',
    'Suspension': 'Shake well before use',
    'Powder': 'Dissolve in water',
    'Injection': 'As directed by doctor',
    'Drops': 'Apply 2 drops',
    'Inhaler': 'Use as directed',
    'Cream': 'Apply thin layer',
    'Ointment': 'Apply gently',
    'Gel': 'Apply to affected area',
    'Lotion': 'Apply externally',
  };

  final List<String> _complaintOptions = [
    'Fever',
    'Cough',
    'Cold',
    'Headache',
    'Body Pain',
    'Sore Throat',
    'Gastric',
    'Vomiting',
    'Diarrhea',
    'Back Pain',
  ];

  final List<String> _diagnosisOptions = [
    'Viral Fever',
    'URTI',
    'Common Cold',
    'Gastritis',
    'Migraine',
    'Viral Infection',
    'Allergic Rhinitis',
    'Pharyngitis',
    'Food Poisoning',
    'Muscle Pain',
  ];

  bool get _isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();

    _followUpNoteController = TextEditingController();

    _consultationFeeController = TextEditingController(
      text: PrescriptionStore.consultationFee.toStringAsFixed(0),
    );

    _patientNameController = TextEditingController(
      text: widget.patientName ?? PrescriptionStore.patientName,
    );
    _patientAgeController = TextEditingController(
      text: widget.patientAge ?? PrescriptionStore.patientAge,
    );
    _patientPhoneController = TextEditingController(
      text: widget.patientPhone ?? PrescriptionStore.patientPhoneNumber,
    );
    _patientAddressController = TextEditingController(
      text: widget.patientAddress ?? PrescriptionStore.patientAddress,
    );
    _patientNotesController =
        TextEditingController(text: PrescriptionStore.patientNotes);

    _complaintController =
        TextEditingController(text: PrescriptionStore.complaint);
    _diagnosisController =
        TextEditingController(text: PrescriptionStore.diagnosis);
    _complaintSearchController = TextEditingController();
    _diagnosisSearchController = TextEditingController();
    _visitNotesController =
        TextEditingController(text: PrescriptionStore.visitNotes);

    _bloodPressureController = TextEditingController();
    _weightController = TextEditingController();
    _pulseController = TextEditingController();
    _temperatureController = TextEditingController();
    _spo2Controller = TextEditingController();

    if ((widget.patientGender ?? '').isNotEmpty) {
      _selectedGender = widget.patientGender!;
    } else if (PrescriptionStore.patientGender.isNotEmpty) {
      _selectedGender = PrescriptionStore.patientGender;
    }

    if (_isEditMode) {
      _currentRxNo = widget.existingRxNo;
      _currentPatientId = widget.existingPatientId;
    }

    _loadPatientMedicalAlerts();

    _syncSelectedClinicalChips();

    _complaintController.addListener(_handleComplaintChanged);
    _diagnosisController.addListener(_handleDiagnosisChanged);

    _loadMasterMedicines();
    _loadCustomInstructions();
    _loadCustomClinicalChips();
    _loadFavoriteTemplates();
  }

  Future<void> _loadCustomInstructions() async {
    loggedDoctorId = await DoctorSession.getDoctorId();

    if (loggedDoctorId == null) return;

    final data = await DatabaseHelper.instance
        .getCustomInstructionsByDoctor(loggedDoctorId!);

    if (!mounted) return;

    setState(() {
      customInstructions = data;
    });
  }

  Future<void> _loadFavoriteTemplates() async {
    final templates = await TemplateService.getFavoriteTemplates();

    if (!mounted) return;

    setState(() {
      _favoriteTemplates = templates;
    });
  }

  Future<void> _loadCustomClinicalChips() async {
    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;

    final complaintChips = await DatabaseHelper.instance.getClinicalChips(
      doctorId: doctorId,
      category: 'complaint',
    );

    final diagnosisChips = await DatabaseHelper.instance.getClinicalChips(
      doctorId: doctorId,
      category: 'diagnosis',
    );

    if (!mounted) return;

    setState(() {
      for (final chip in complaintChips) {
        if (!_complaintOptions.contains(chip)) {
          _complaintOptions.add(chip);
        }
      }

      for (final chip in diagnosisChips) {
        if (!_diagnosisOptions.contains(chip)) {
          _diagnosisOptions.add(chip);
        }
      }
    });
  }

  List<String> _allInstructionSuggestions() {
    final defaults = defaultInstructions.values.toSet().toList();

    final customs = customInstructions
        .map((e) => e['instruction_text']?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();

    return [...defaults, ...customs];
  }

  Future<void> _saveCustomInstruction(String text) async {
    final value = text.trim();

    if (value.isEmpty) return;

    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;

    final exists = customInstructions.any(
      (e) =>
          (e['instruction_text']?.toString().toLowerCase() ?? '') ==
          value.toLowerCase(),
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instruction already exists')),
      );
      return;
    }

    try {
      await DatabaseHelper.instance.insertCustomInstruction({
        'doctor_id': doctorId,
        'instruction_text': value,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instruction already exists')),
      );
      return;
    }
    unawaited(AutoSyncService.syncPendingChanges());

    await _loadCustomInstructions();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom instruction saved')),
    );
  }

  @override
  void dispose() {
    _followUpNoteController.dispose();
    _consultationFeeController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _patientPhoneController.dispose();
    _patientAddressController.dispose();
    _patientNotesController.dispose();

    _complaintController.dispose();
    _diagnosisController.dispose();
    _complaintSearchController.dispose();
    _diagnosisSearchController.dispose();
    _visitNotesController.dispose();

    _bloodPressureController.dispose();
    _weightController.dispose();
    _pulseController.dispose();
    _temperatureController.dispose();
    _spo2Controller.dispose();

    super.dispose();
  }

  void _syncSelectedClinicalChips() {
    _selectedComplaintChips
      ..clear()
      ..addAll(
        _extractSelectedOptions(
          _complaintController.text,
          _complaintOptions,
        ),
      );

    _selectedDiagnosisChips
      ..clear()
      ..addAll(
        _extractSelectedOptions(
          _diagnosisController.text,
          _diagnosisOptions,
        ),
      );
  }

  List<String> _extractSelectedOptions(
    String value,
    List<String> options,
  ) {
    final enteredValues = value
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();

    return options
        .where(
          (option) => enteredValues.contains(option.toLowerCase()),
        )
        .toList();
  }

  List<String> _getSuggestions(
    String value,
    List<String> options,
    List<String> selectedChips,
  ) {
    final normalized = value.split(',').last.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    return options
        .where(
          (option) =>
              option.toLowerCase().contains(normalized) &&
              !selectedChips.contains(option),
        )
        .toList();
  }

  void _handleComplaintChanged() {
    final selected = _extractSelectedOptions(
      _complaintController.text,
      _complaintOptions,
    );

    setState(() {
      _selectedComplaintChips
        ..clear()
        ..addAll(selected);
    });

    _savePatientDetailsToStore();
  }

  void _handleDiagnosisChanged() {
    final selected = _extractSelectedOptions(
      _diagnosisController.text,
      _diagnosisOptions,
    );

    setState(() {
      _selectedDiagnosisChips
        ..clear()
        ..addAll(selected);
    });

    _savePatientDetailsToStore();
  }

  void _selectComplaintChip(String value) {
    setState(() {
      if (_selectedComplaintChips.contains(value)) {
        _selectedComplaintChips.remove(value);
      } else {
        _selectedComplaintChips.add(value);
      }

      _complaintController.text = _selectedComplaintChips.join(', ');
      _complaintController.selection = TextSelection.fromPosition(
        TextPosition(offset: _complaintController.text.length),
      );
    });

    _savePatientDetailsToStore();
  }

  void _selectDiagnosisChip(String value) {
    setState(() {
      if (_selectedDiagnosisChips.contains(value)) {
        _selectedDiagnosisChips.remove(value);
      } else {
        _selectedDiagnosisChips.add(value);
      }

      _diagnosisController.text = _selectedDiagnosisChips.join(', ');
      _diagnosisController.selection = TextSelection.fromPosition(
        TextPosition(offset: _diagnosisController.text.length),
      );
    });

    _savePatientDetailsToStore();
  }

  void _savePatientDetailsToStore() {
    PrescriptionStore.setPatientDetails(
      name: _patientNameController.text.trim(),
      age: _patientAgeController.text.trim(),
      gender: _selectedGender,
      phoneNumber: _patientPhoneController.text.trim(),
      address: _patientAddressController.text.trim(),
      notes: _patientNotesController.text.trim(),
    );

    PrescriptionStore.setClinicalDetails(
      complaintText: _complaintController.text.trim(),
      diagnosisText: _diagnosisController.text.trim(),
      visitNotesText: _visitNotesController.text.trim(),
    );
  }

  Future<void> _loadMasterMedicines() async {
    loggedDoctorId = await DoctorSession.getDoctorId();

    if (loggedDoctorId == null) return;

    final data =
        await DatabaseHelper.instance.getMedicinesByDoctor(loggedDoctorId!);

    if (!mounted) return;

    setState(() {
      masterMedicines = data;
    });
  }

  String _patientAllergyText() {
    final allergyFromChips = selectedAllergies.join(', ');
    return allergyFromChips.toLowerCase();
  }

  Future<void> _loadPatientMedicalAlerts() async {
    final patientId = _currentPatientId ?? widget.existingPatientId;
    if (patientId == null) return;

    final patient = await DatabaseHelper.instance.getPatientById(patientId);
    if (patient == null || !mounted) return;

    final allergies = (patient['allergies'] ?? '')
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final diseases = (patient['chronic_diseases'] ?? '')
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    setState(() {
      selectedAllergies = allergies;
      selectedDiseases = diseases;
    });
  }

  List<String> _matchingAllergies(Map<String, dynamic> medicine) {
    final drugGroup =
        medicine['drug_group']?.toString().trim().toLowerCase() ?? '';

    if (drugGroup.isEmpty) return [];

    return selectedAllergies.where((allergy) {
      final normalized = allergy.trim().toLowerCase();
      if (normalized.isEmpty) return false;

      return drugGroup.contains(normalized) || normalized.contains(drugGroup);
    }).toList();
  }

  Future<bool> _checkAllergyBeforeAdd(Map<String, dynamic> medicine) async {
    final drugGroup =
        medicine['drug_group']?.toString().trim().toLowerCase() ?? '';

    if (drugGroup.isEmpty) return true;

    final matchedAllergies = _matchingAllergies(medicine);
    if (matchedAllergies.isEmpty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Allergy Warning'),
        content: Text(
          'Patient allergies: ${selectedAllergies.join(', ')}\n\n'
          'Matched allergy: ${matchedAllergies.join(', ')}\n\n'
          '${medicine['medicine_name']} belongs to "$drugGroup" group.\n\n'
          'Do you still want to add this medicine?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add Anyway'),
          ),
        ],
      ),
    );

    return result == true;
  }

  String _cleanDurationForEdit(String duration) {
    return duration.replaceAll(' days', '').trim();
  }

  String _buildDurationValue(
    String value,
    String unit,
  ) {
    final clean = value.trim();

    if (clean.isEmpty) return '';

    switch (unit) {
      case 'Days':
        return '$clean/365';

      case 'Weeks':
        return '$clean/52';

      case 'Months':
        return '$clean/12';

      case 'Years':
        return '$clean/1';

      default:
        return clean;
    }
  }

  Future<void> _openMedicinePicker() async {
    _savePatientDetailsToStore();

    if (masterMedicines.isEmpty) {
      await _loadMasterMedicines();
    }

    if (!mounted) return;

    if (masterMedicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No medicines found. Add medicines from Medicine Master first.',
          ),
        ),
      );
      return;
    }

    Map<String, dynamic>? selected;

    List<Map<String, dynamic>> filteredMedicines = List.from(masterMedicines);

    filteredMedicines.sort((a, b) {
      final favA = a['is_favorite'] ?? 0;
      final favB = b['is_favorite'] ?? 0;
      return favB.compareTo(favA);
    });

    if (selectedMedicine != null) {
      selected = selectedMedicine;
    } else if (filteredMedicines.isNotEmpty) {
      selected = filteredMedicines.first;
    }

    final searchController = TextEditingController();

    final dosageController = TextEditingController(
      text: selected?['strength']?.toString() ?? '',
    );

    final durationController = TextEditingController(text: '5');
    final quantityController = TextEditingController(text: '1');

    String selectedDurationUnit = 'Days';

    final initialDoseForm = selected?['dose_form']?.toString() ?? '';

    final instructionsController = TextEditingController(
      text: defaultInstructions[initialDoseForm] ?? '',
    );

    String selectedFrequency = 'BD';
    bool prescriptionOnly = false;

    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final instructionValue = instructionsController.text.trim();

            final instructionSuggestions = _allInstructionSuggestions();

            final dropdownValue =
                instructionSuggestions.contains(instructionValue)
                    ? instructionValue
                    : null;

            return AlertDialog(
              backgroundColor: const Color(0xFFF8FAFC),
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              title: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Medicine',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select medicine and set directions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.70,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedAllergies.isEmpty
                              ? Colors.green.withOpacity(0.08)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedAllergies.isEmpty
                                ? Colors.green.withOpacity(0.30)
                                : Colors.red.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selectedAllergies.isEmpty
                                  ? Icons.verified_outlined
                                  : Icons.warning_amber_rounded,
                              color: selectedAllergies.isEmpty
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedAllergies.isEmpty
                                        ? 'No known allergies recorded'
                                        : 'Patient Allergy Alert',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selectedAllergies.isEmpty
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                  if (selectedAllergies.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedAllergies.join('  •  '),
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Check the drug group before adding medicine.',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Search Medicine',
                          hintText: 'Type medicine / group / brand',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() {
                                      filteredMedicines =
                                          List.from(masterMedicines);
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F766E),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          final q = value.trim().toLowerCase();

                          setDialogState(() {
                            filteredMedicines = masterMedicines.where((m) {
                              final name = m['medicine_name']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';

                              final generic =
                                  m['generic_name']?.toString().toLowerCase() ??
                                      '';

                              final brand =
                                  m['brand_name']?.toString().toLowerCase() ??
                                      '';

                              final group =
                                  m['drug_group']?.toString().toLowerCase() ??
                                      '';

                              final strength =
                                  m['strength']?.toString().toLowerCase() ?? '';

                              return name.contains(q) ||
                                  generic.contains(q) ||
                                  brand.contains(q) ||
                                  group.contains(q) ||
                                  strength.contains(q);
                            }).toList();

                            filteredMedicines.sort((a, b) {
                              final favA = a['is_favorite'] ?? 0;

                              final favB = b['is_favorite'] ?? 0;

                              return favB.compareTo(favA);
                            });
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 230,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: filteredMedicines.isEmpty
                            ? const Center(
                                child: Text('No medicine found'),
                              )
                            : ListView.builder(
                                itemCount: filteredMedicines.length,
                                itemBuilder: (context, index) {
                                  final med = filteredMedicines[index];

                                  final isSelected =
                                      selected?['id'] == med['id'];

                                  final isFav = (med['is_favorite'] ?? 0) == 1;

                                  final name =
                                      med['medicine_name']?.toString() ?? '';

                                  final matchedAllergies =
                                      _matchingAllergies(med);

                                  final hasAllergyRisk =
                                      matchedAllergies.isNotEmpty;

                                  return Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      8,
                                      6,
                                      8,
                                      2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasAllergyRisk
                                          ? Colors.red.withOpacity(0.05)
                                          : isSelected
                                              ? const Color(0xFFE6FFFB)
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: hasAllergyRisk
                                            ? Colors.red.shade300
                                            : isSelected
                                                ? const Color(0xFF14B8A6)
                                                : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: ListTile(
                                      selected: isSelected,
                                      selectedTileColor: const Color(0xFF0F766E)
                                          .withOpacity(0.12),
                                      leading: Icon(
                                        isFav
                                            ? Icons.star
                                            : Icons.medication_outlined,
                                        color: isFav
                                            ? Colors.amber
                                            : const Color(0xFF0F766E),
                                      ),
                                      title: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        hasAllergyRisk
                                            ? '${med['strength'] ?? ''} ${med['drug_group'] ?? ''}\n'
                                                '⚠ Allergy risk: ${matchedAllergies.join(', ')}'
                                            : '${med['strength'] ?? ''} ${med['drug_group'] ?? ''}',
                                        style: TextStyle(
                                          color: hasAllergyRisk
                                              ? Colors.red.shade700
                                              : null,
                                          fontWeight: hasAllergyRisk
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      trailing: hasAllergyRisk
                                          ? const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.red,
                                            )
                                          : isSelected
                                              ? const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                )
                                              : null,
                                      onTap: () {
                                        setDialogState(() {
                                          selected = med;

                                          dosageController.text =
                                              med['strength']?.toString() ?? '';

                                          final doseForm =
                                              med['dose_form']?.toString() ??
                                                  '';

                                          final defaultInstruction =
                                              defaultInstructions[doseForm] ??
                                                  '';

                                          instructionsController.text =
                                              defaultInstruction;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Prescription details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Dosage',
                          hintText: 'Example: 500mg',
                          prefixIcon: Icon(Icons.science_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: Icon(Icons.schedule_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'OD',
                            child: Text('OD - Once Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'BD',
                            child: Text('BD - Twice Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'TDS',
                            child: Text('TDS - Three Times Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'QID',
                            child: Text('QID - Four Times Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'HS',
                            child: Text('HS - Night'),
                          ),
                          DropdownMenuItem(
                            value: 'SOS',
                            child: Text('SOS - When Needed'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(
                            () => selectedFrequency = value,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                hintText: '5',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedDurationUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Days', child: Text('Days')),
                                DropdownMenuItem(
                                    value: 'Weeks', child: Text('Weeks')),
                                DropdownMenuItem(
                                    value: 'Months', child: Text('Months')),
                                DropdownMenuItem(
                                    value: 'Years', child: Text('Years')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedDurationUnit = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          hintText: '1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                          hintText: 'After meals / Before meals',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: prescriptionOnly,
                        onChanged: (value) {
                          setDialogState(() {
                            prescriptionOnly = value ?? false;
                          });
                        },
                        title: const Text(
                          'Prescription only (Do not add to bill)',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Add to Prescription'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added != true || selected == null) {
      searchController.dispose();
      dosageController.dispose();
      durationController.dispose();
      instructionsController.dispose();
      quantityController.dispose();
      return;
    }

    final canAdd = await _checkAllergyBeforeAdd(selected!);

    if (!canAdd) {
      searchController.dispose();
      dosageController.dispose();
      durationController.dispose();
      instructionsController.dispose();
      quantityController.dispose();
      return;
    }

    setState(() {
      selectedMedicine = selected;

      PrescriptionStore.add(
        PrescriptionItem(
          medicineId: int.tryParse(
            selected!['server_id']?.toString() ?? '',
          ),
          medicineName: selected!['medicine_name'].toString(),
          dosage: dosageController.text.trim(),
          frequency: selectedFrequency,
          duration: _buildDurationValue(
            durationController.text,
            selectedDurationUnit,
          ),
          instructions: instructionsController.text.trim(),
          prescriptionOnly: prescriptionOnly,
          unitPrice: prescriptionOnly
              ? 0
              : double.tryParse(
                    selected!['selling_price']?.toString() ?? '0',
                  ) ??
                  0,
          quantity: prescriptionOnly
              ? 0
              : double.tryParse(
                    quantityController.text.trim(),
                  ) ??
                  1,
          lineTotal: prescriptionOnly
              ? 0
              : (double.tryParse(
                        selected!['selling_price']?.toString() ?? '0',
                      ) ??
                      0) *
                  (double.tryParse(
                        quantityController.text.trim(),
                      ) ??
                      1),
        ),
      );
    });

    searchController.dispose();
    dosageController.dispose();
    durationController.dispose();
    instructionsController.dispose();
    quantityController.dispose();
  }

  Future<void> _ensureRxNumber() async {
    if (_isEditMode) {
      _currentRxNo = widget.existingRxNo;
      return;
    }

    if (_currentRxNo != null && _currentRxNo!.isNotEmpty) return;

    _currentRxNo = await PrescriptionStore.generatePersistentRxNumber();
  }

  Future<void> _savePrescriptionToDb() async {
    try {
      _savePatientDetailsToStore();

      final doctorId = await DoctorSession.getDoctorId();

      if (doctorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor session not found. Login again.'),
          ),
        );
        return;
      }

      final items = PrescriptionStore.items;

      if (_patientNameController.text.trim().isEmpty ||
          _patientAgeController.text.trim().isEmpty ||
          items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter patient details and add medicines first'),
          ),
        );
        return;
      }

      await _ensureRxNumber();

      final patientName = _patientNameController.text.trim();
      final patientAge = _patientAgeController.text.trim();
      final patientGender = _selectedGender;
      final phone = _patientPhoneController.text.trim();
      final address = _patientAddressController.text.trim();
      final notes = _patientNotesController.text.trim();

      final patientData = {
        'doctor_id': doctorId,
        'patient_name': patientName,
        'patient_age': patientAge,
        'patient_gender': patientGender,
        'phone_number': phone.isEmpty ? null : phone,
        'address': address.isEmpty ? null : address,
        'notes': notes.isEmpty ? null : notes,
        'allergies':
            selectedAllergies.isEmpty ? null : selectedAllergies.join(', '),
        'chronic_diseases':
            selectedDiseases.isEmpty ? null : selectedDiseases.join(', '),
        'created_at': DateTime.now().toIso8601String(),
      };

      int localPatientId;

      final existingByPhone = phone.isEmpty
          ? null
          : await DatabaseHelper.instance.getPatientByPhoneAndDoctor(
              phone,
              doctorId,
            );

      if (existingByPhone != null) {
        localPatientId = existingByPhone['id'] as int;
        await DatabaseHelper.instance
            .updatePatient(localPatientId, patientData);
      } else {
        localPatientId =
            await DatabaseHelper.instance.insertPatient(patientData);
      }

      _currentPatientId = localPatientId;

      final currentDate = DateTime.now().toString().substring(0, 10);

      final itemsText = items.map((item) {
        return '${item.medicineName} | ${item.dosage} | ${item.frequency} | ${item.duration} | ${item.instructions}';
      }).join('\n');

      final prescriptionData = {
        'doctor_id': doctorId,
        'patient_id': localPatientId,
        'patient_name': patientName,
        'patient_age': patientAge,
        'patient_gender': patientGender,
        'prescription_no': _currentRxNo,
        'prescription_date': currentDate,
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
        'blood_pressure': _bloodPressureController.text.trim().isEmpty
            ? null
            : _bloodPressureController.text.trim(),
        'weight': _weightController.text.trim().isEmpty
            ? null
            : _weightController.text.trim(),
        'pulse': _pulseController.text.trim().isEmpty
            ? null
            : _pulseController.text.trim(),
        'temperature': _temperatureController.text.trim().isEmpty
            ? null
            : _temperatureController.text.trim(),
        'spo2': _spo2Controller.text.trim().isEmpty
            ? null
            : _spo2Controller.text.trim(),
        'server_patient_id': null,
        'follow_up_date': _followUpDate?.toIso8601String(),
        'follow_up_note': _followUpNoteController.text.trim().isEmpty
            ? null
            : _followUpNoteController.text.trim(),
        'follow_up_status': 'pending',
        'reminder_sent': 0,
      };

      int localPrescriptionId;

      if (_isEditMode && widget.editingPrescriptionId != null) {
        localPrescriptionId = widget.editingPrescriptionId!;

        await DatabaseHelper.instance.updatePrescription(
          localPrescriptionId,
          prescriptionData,
        );
      } else {
        localPrescriptionId =
            await DatabaseHelper.instance.insertPrescription(prescriptionData);
      }

      _currentPrescriptionId = localPrescriptionId;

      final itemRows = items.map((item) {
        return {
          'medicine_id': item.medicineId,
          'medicine_name': item.medicineName,
          'dosage': item.dosage,
          'frequency': item.frequency,
          'duration': item.duration,
          'instructions': item.instructions,
          'prescription_only': item.prescriptionOnly ? 1 : 0,
          'unit_price': item.unitPrice,
          'quantity': item.quantity,
          'line_total': item.lineTotal,
        };
      }).toList();

      await DatabaseHelper.instance.replacePrescriptionItems(
        localPrescriptionId,
        itemRows,
      );
      if (_followUpDate != null && _enableAppReminder) {
        await LocalNotificationService.scheduleFollowUpNotification(
          id: localPrescriptionId,
          patientName: patientName,
          reason: _followUpNoteController.text.trim(),
          date: _followUpDate!,
        );
      }

      if (!mounted) return;

      setState(() {
        _prescriptionSaved = true;
      });

      final message = _isEditMode
          ? 'Prescription updated successfully ✅'
          : 'Prescription saved successfully ✅';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      final online = await NetworkService.isOnline();

      if (online) {
        try {
          await SyncService().syncAll();
        } catch (_) {}
      }

      if (widget.existingPatientId != null) {
        try {
          await _patientApi.completePatient(
            widget.existingPatientId!,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {});
      }

//_resetFormAfterSave();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  void _resetFormAfterSave() {
    setState(() {
      _followUpNoteController.clear();
      _followUpDate = null;
      _enableAppReminder = true;
      _enableWhatsappReminder = false;
      _enableSmsReminder = false;
      PrescriptionStore.clear();

      _patientNameController.clear();
      _patientAgeController.clear();
      _patientPhoneController.clear();
      _patientAddressController.clear();
      _patientNotesController.clear();

      _complaintController.clear();
      _diagnosisController.clear();
      _visitNotesController.clear();

      _bloodPressureController.clear();
      _weightController.clear();
      _pulseController.clear();
      _temperatureController.clear();
      _spo2Controller.clear();

      _selectedGender = 'Male';
      _selectedComplaintChips.clear();
      _selectedDiagnosisChips.clear();

      selectedAllergies = [];
      selectedDiseases = [];

      selectedMedicine = null;
      _prescriptionSaved = false;
      _currentRxNo = null;
      _currentPatientId = null;
      _currentPrescriptionId = null;
    });
  }

  Future<void> _openLabInvestigations() async {
    final localPatientId = _currentPatientId ?? widget.existingPatientId;
    final localPrescriptionId = _currentPrescriptionId ?? widget.editingPrescriptionId;
    if (localPatientId == null || localPrescriptionId == null || !_prescriptionSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save and sync the prescription before adding lab investigations')),
      );
      return;
    }

    try {
      if (await NetworkService.isOnline()) await SyncService().syncAll();
      final patient = await DatabaseHelper.instance.getPatientById(localPatientId);
      final prescription = await DatabaseHelper.instance.getPrescriptionByLocalId(localPrescriptionId);
      final serverPatientId = int.tryParse(patient?['server_id']?.toString() ?? '');
      final serverPrescriptionId = int.tryParse(prescription?['server_id']?.toString() ?? '');
      if (serverPatientId == null || serverPrescriptionId == null) {
        throw Exception('Prescription is waiting for cloud sync');
      }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLabOrderScreen(
        patientId: serverPatientId,
        prescriptionId: serverPrescriptionId,
        patientName: _patientNameController.text.trim(),
      )));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lab request unavailable: $e')));
    }
  }

  Future<void> _saveAsTemplate() async {
    _savePatientDetailsToStore();

    if (PrescriptionStore.items.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add medicines first')),
      );
      return;
    }

    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Template Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Ex: Fever Case'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, nameController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    final items = PrescriptionStore.items.map((e) {
      return {
        'name': e.medicineName,
        'dosage': e.dosage,
        'frequency': e.frequency,
        'duration': e.duration,
        'instructions': e.instructions,
      };
    }).toList();

    final template = TemplateModel(
      name: result,
      complaint: PrescriptionStore.complaint,
      diagnosis: PrescriptionStore.diagnosis,
      itemsJson: TemplateService.encodeItems(items),
      isFavorite: true,
    );

    try {
      await TemplateService.saveTemplate(template);
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved')),
    );
  }

  void _openMedicinesScreen() {
    _openMedicinePicker();
  }

  void _applyFavoriteTemplate(TemplateModel template) {
    _savePatientDetailsToStore();

    final items = TemplateService.decodeItems(template.itemsJson);

    setState(() {
      _complaintController.text = template.complaint;
      _diagnosisController.text = template.diagnosis;

      PrescriptionStore.setClinicalDetails(
        complaintText: template.complaint,
        diagnosisText: template.diagnosis,
        visitNotesText: PrescriptionStore.visitNotes,
      );

      for (final item in items) {
        PrescriptionStore.add(
          PrescriptionItem(
            medicineName: item['name']?.toString() ?? '',
            dosage: item['dosage']?.toString() ?? '',
            frequency: item['frequency']?.toString() ?? '',
            duration: item['duration']?.toString() ?? '',
            instructions: item['instructions']?.toString() ?? '',
          ),
        );
      }

      _syncSelectedClinicalChips();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${template.name} template applied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openTemplateScreen() {
    _savePatientDetailsToStore();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateListScreen()),
    ).then((value) {
      _complaintController.text = PrescriptionStore.complaint;
      _diagnosisController.text = PrescriptionStore.diagnosis;
      _visitNotesController.text = PrescriptionStore.visitNotes;
      _syncSelectedClinicalChips();
      setState(() {});
    });
  }

  Future<void> _openPrintPreview() async {
    _savePatientDetailsToStore();
    await _ensureRxNumber();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          passedRxNo: _currentRxNo,
          passedDate: _isEditMode
              ? widget.existingDate
              : DateTime.now().toString().substring(0, 10),
          allowBillSave: true,
        ),
      ),
    );
  }

  Future<void> _editMedicineItem(int index) async {
    final item = PrescriptionStore.items[index];

    final dosageController = TextEditingController(text: item.dosage);
    final durationController = TextEditingController(
      text: _cleanDurationForEdit(item.duration),
    );

    String selectedDurationUnit = 'Days';

    if (item.duration.contains('/52')) {
      selectedDurationUnit = 'Weeks';
    } else if (item.duration.contains('/12')) {
      selectedDurationUnit = 'Months';
    } else if (item.duration.contains('/1')) {
      selectedDurationUnit = 'Years';
    }
    final instructionsController =
        TextEditingController(text: item.instructions);

    String selectedFrequency = item.frequency;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${item.medicineName}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(labelText: 'Dosage'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'OD',
                          child: Text('OD - Once Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'BD',
                          child: Text('BD - Twice Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'TDS',
                          child: Text('TDS - Three Times Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'QID',
                          child: Text('QID - Four Times Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'HS',
                          child: Text('HS - Night'),
                        ),
                        DropdownMenuItem(
                          value: 'SOS',
                          child: Text('SOS - When Needed'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedFrequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration',
                              hintText: '5',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedDurationUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Days',
                                child: Text('Days'),
                              ),
                              DropdownMenuItem(
                                value: 'Weeks',
                                child: Text('Weeks'),
                              ),
                              DropdownMenuItem(
                                value: 'Months',
                                child: Text('Months'),
                              ),
                              DropdownMenuItem(
                                value: 'Years',
                                child: Text('Years'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedDurationUnit = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructionsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        PrescriptionStore.items[index] = PrescriptionItem(
          medicineId: item.medicineId,
          medicineName: item.medicineName,
          dosage: dosageController.text.trim(),
          frequency: selectedFrequency,
          duration: _buildDurationValue(
            durationController.text,
            selectedDurationUnit,
          ),
          instructions: instructionsController.text.trim(),
          prescriptionOnly: item.prescriptionOnly,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          lineTotal: item.lineTotal,
        );
      });
    }

    dosageController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }

  Future<void> _addClinicalOption({
    required String title,
    required List<String> options,
    required TextEditingController controller,
    required ValueChanged<String> onChipSelected,
  }) async {
    final newController = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Add $title'),
          content: TextField(
            controller: newController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: title,
              hintText: 'Enter new $title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  newController.text.trim(),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    newController.dispose();

    if (value == null || value.trim().isEmpty) return;

    final cleanValue = value.trim();
    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;

    await DatabaseHelper.instance.insertClinicalChip(
      doctorId: doctorId,
      category: title.toLowerCase(),
      value: cleanValue,
    );

    setState(() {
      if (!options.contains(cleanValue)) {
        options.add(cleanValue);
      }
    });

    onChipSelected(cleanValue);

    _savePatientDetailsToStore();
  }

  Future<void> _deleteClinicalOption({
    required String title,
    required String value,
    required List<String> options,
  }) async {
    final defaultComplaintOptions = [
      'Fever',
      'Cough',
      'Cold',
      'Headache',
      'Body Pain',
      'Sore Throat',
      'Gastric',
      'Vomiting',
      'Diarrhea',
      'Back Pain',
    ];

    final defaultDiagnosisOptions = [
      'Viral Fever',
      'URTI',
      'Common Cold',
      'Gastritis',
      'Migraine',
      'Viral Infection',
      'Allergic Rhinitis',
      'Pharyngitis',
      'Food Poisoning',
      'Muscle Pain',
    ];

    final isDefault = title == 'Complaint'
        ? defaultComplaintOptions.contains(value)
        : defaultDiagnosisOptions.contains(value);

    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default chips cannot be deleted'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete Chip'),
          content: Text(
            'Delete "$value" from $title?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;

    await DatabaseHelper.instance.deleteClinicalChip(
      doctorId: doctorId,
      category: title.toLowerCase(),
      value: value,
    );

    setState(() {
      options.remove(value);

      if (title == 'Complaint') {
        _selectedComplaintChips.remove(value);
        _complaintController.text = _selectedComplaintChips.join(', ');
      }

      if (title == 'Diagnosis') {
        _selectedDiagnosisChips.remove(value);
        _diagnosisController.text = _selectedDiagnosisChips.join(', ');
      }
    });

    _savePatientDetailsToStore();
  }

  Widget _buildSmartClinicalField({
    required String title,
    required String hintText,
    required TextEditingController controller,
    required TextEditingController searchController,
    required List<String> options,
    required List<String> selectedChips,
    required ValueChanged<String> onChipSelected,
    IconData? icon,
  }) {
    final searchText = searchController.text.trim().toLowerCase();
    final visibleOptions = searchText.isEmpty
        ? List<String>.from(options)
        : options
            .where((option) => option.toLowerCase().contains(searchText))
            .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF0F766E),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _addClinicalOption(
                    title: title,
                    options: options,
                    controller: controller,
                    onChipSelected: onChipSelected,
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search $title',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (visibleOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No matching option found',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = visibleOptions[index];
                  final isSelected = selectedChips.contains(option);

                  return GestureDetector(
                    onLongPress: () {
                      _deleteClinicalOption(
                        title: title,
                        value: option,
                        options: options,
                      );
                    },
                    child: FilterChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (_) {
                        onChipSelected(option);
                        searchController.clear();
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Selected $title',
              hintText: hintText,
              prefixIcon: const Icon(Icons.edit_note_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (_) => _savePatientDetailsToStore(),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMedicalAssist() {
    return ExpansionTile(
      key: ValueKey('medical-alerts-${selectedAllergies.join('|')}'),
      initiallyExpanded:
          selectedAllergies.isNotEmpty || selectedDiseases.isNotEmpty,
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(
            selectedAllergies.isEmpty
                ? Icons.health_and_safety_outlined
                : Icons.warning_amber_rounded,
            color: selectedAllergies.isEmpty
                ? const Color(0xFF0F766E)
                : Colors.red,
          ),
          const SizedBox(width: 8),
          const Text(
            'Allergies & Medical Alerts',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text(
        selectedAllergies.isEmpty && selectedDiseases.isEmpty
            ? 'No allergies or chronic diseases recorded'
            : selectedAllergies.isEmpty
                ? 'Diseases: ${selectedDiseases.join(', ')}'
                : '⚠ Allergies: ${selectedAllergies.join(', ')}',
        style: TextStyle(
          color: selectedAllergies.isEmpty ? null : Colors.red.shade700,
          fontWeight:
              selectedAllergies.isEmpty ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      children: [
        const SizedBox(height: 8),
        SmartChipsSection(
          initialAllergies: selectedAllergies,
          initialDiseases: selectedDiseases,
          onChanged: (allergies, diseases) {
            setState(() {
              selectedAllergies = List<String>.from(allergies);
              selectedDiseases = List<String>.from(diseases);
            });
          },
        ),
      ],
    );
  }

  Widget _buildVisitDetailsSection() {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: const Row(
        children: [
          Icon(Icons.monitor_heart_outlined, color: Colors.red),
          SizedBox(width: 8),
          Text(
            'Visit Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: const Text('BP, weight, pulse, temperature, SpO2'),
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'SYS',
                        hintText: '120',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        final current =
                            _bloodPressureController.text.split('/');

                        final dia = current.length > 1 ? current[1] : '';

                        _bloodPressureController.text = '$value/$dia';
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '/',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'DIA',
                        hintText: '80',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        final current =
                            _bloodPressureController.text.split('/');

                        final sys = current.isNotEmpty ? current[0] : '';

                        _bloodPressureController.text = '$sys/$value';
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Weight',
                  hintText: '70 kg',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pulseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pulse',
                  hintText: '78',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _temperatureController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Temperature',
                  hintText: '98.6',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _spo2Controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'SpO2',
            hintText: '98%',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  void _clearForm() {
    setState(() {
      PrescriptionStore.clear();

      _patientNameController.clear();
      _patientAgeController.clear();
      _patientPhoneController.clear();
      _patientAddressController.clear();
      _patientNotesController.clear();

      _complaintController.clear();
      _diagnosisController.clear();
      _visitNotesController.clear();

      _bloodPressureController.clear();
      _weightController.clear();
      _pulseController.clear();
      _temperatureController.clear();
      _spo2Controller.clear();

      _selectedGender = 'Male';
      _selectedComplaintChips.clear();
      _selectedDiagnosisChips.clear();

      selectedAllergies = [];
      selectedDiseases = [];

      selectedMedicine = null;

      _currentRxNo = _isEditMode ? widget.existingRxNo : null;
      _currentPatientId = _isEditMode ? widget.existingPatientId : null;
    });
  }

  Widget _buildPatientDetailsSection() {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: const Row(
        children: [
          Icon(Icons.person_outline, color: Color(0xFF0F766E)),
          SizedBox(width: 8),
          Text(
            'Patient Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text(
        '${_patientNameController.text} • ${_patientAgeController.text} • $_selectedGender',
      ),
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _patientNameController,
          decoration: InputDecoration(
            labelText: 'Patient Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (_) => _savePatientDetailsToStore(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _patientAgeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _savePatientDetailsToStore(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text('Male'),
                  ),
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text('Female'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedGender = value;
                  });

                  _savePatientDetailsToStore();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _patientPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (_) => _savePatientDetailsToStore(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _patientAddressController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (_) => _savePatientDetailsToStore(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _patientNotesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Patient Notes',
            hintText: 'Allergy / Chronic disease notes',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onChanged: (_) => _savePatientDetailsToStore(),
        ),
      ],
    );
  }

  Widget _buildFollowUpSection() {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: const Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Colors.orange,
          ),
          SizedBox(width: 8),
          Text(
            'Follow-Up Reminder',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text(
        _followUpDate == null
            ? 'Tap to add follow-up reminder'
            : 'Follow-up: ${_followUpDate!.toString().substring(0, 10)}',
      ),
      children: [
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(
                const Duration(days: 7),
              ),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );

            if (picked == null) return;

            setState(() {
              _followUpDate = picked;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month),
                const SizedBox(width: 10),
                Text(
                  _followUpDate == null
                      ? 'Select Follow-Up Date'
                      : _followUpDate!.toString().substring(0, 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _followUpNoteController,
          decoration: InputDecoration(
            labelText: 'Follow-Up Reason',
            hintText: 'BP Review / Diabetes Review',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _enableAppReminder,
          onChanged: (v) {
            setState(() {
              _enableAppReminder = v ?? false;
            });
          },
          title: const Text('App Notification'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _enableWhatsappReminder,
          onChanged: (v) {
            setState(() {
              _enableWhatsappReminder = v ?? false;
            });
          },
          title: const Text('WhatsApp Reminder'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _enableSmsReminder,
          onChanged: (v) {
            setState(() {
              _enableSmsReminder = v ?? false;
            });
          },
          title: const Text('SMS Reminder (Future)'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildBillingSection() {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: const Row(
        children: [
          Icon(Icons.payments_outlined, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'Billing',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text(
        'Channeling Fee: Rs. ${PrescriptionStore.consultationFee.toStringAsFixed(2)}',
      ),
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _consultationFeeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Channeling Fee',
            hintText: '1500',
            prefixText: 'Rs. ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: (value) {
            final fee = double.tryParse(value.trim()) ?? 0;
            PrescriptionStore.setConsultationFee(fee);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildFavoriteTemplatesSection() {
    if (_favoriteTemplates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withOpacity(0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Quick Templates',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _favoriteTemplates.map((template) {
              return ActionChip(
                avatar: const Icon(
                  Icons.flash_on,
                  size: 18,
                  color: Colors.orange,
                ),
                label: Text(template.name),
                onPressed: () => _applyFavoriteTemplate(template),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _premiumCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7ECF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = const Color(0xFF0F766E),
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF14213D),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildPrescriptionHeader(int medicineCount) {
    final patientName = _patientNameController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF075E54),
            Color(0xFF0F766E),
            Color(0xFF22A06B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode
                          ? 'Update clinical record'
                          : 'New clinical record',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patientName.isEmpty
                          ? 'Select patient details'
                          : patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$medicineCount medicine${medicineCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerPill(
                icon: Icons.badge_outlined,
                text: _currentRxNo == null || _currentRxNo!.isEmpty
                    ? 'Rx generated on save'
                    : 'Rx: $_currentRxNo',
              ),
              _headerPill(
                icon: _isEditMode ? Icons.edit_note : Icons.add_circle_outline,
                text: _isEditMode ? 'Edit mode' : 'New prescription',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(int index, PrescriptionItem item) {
    return Dismissible(
      key: ObjectKey(item),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Remove Medicine'),
                  content: Text(
                    'Remove "${item.medicineName}" from this prescription?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Remove'),
                    ),
                  ],
                );
              },
            ) ??
            false;
      },
      onDismissed: (_) {
        setState(() {
          PrescriptionStore.items.remove(item);
        });
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _editMedicineItem(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FBFF),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE5ECF6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.medicineName,
                            style: const TextStyle(
                              color: Color(0xFF14213D),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (item.prescriptionOnly)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Rx only',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.dosage}  •  ${item.frequency}  •  ${item.duration}',
                      style: const TextStyle(
                        color: Color(0xFF5F6B7A),
                        fontSize: 13,
                      ),
                    ),
                    if (item.instructions.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.instructions,
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (!item.prescriptionOnly) ...[
                      const SizedBox(height: 7),
                      Text(
                        'Qty ${item.quantity.toStringAsFixed(0)}  •  '
                        'Rs. ${item.lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Medicine actions',
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF718096),
                ),
                onSelected: (action) {
                  if (action == 'edit') {
                    _editMedicineItem(index);
                  } else if (action == 'delete') {
                    setState(
                      () => PrescriptionStore.items.remove(item),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = PrescriptionStore.items;
    final medicineTotal = items
        .where((item) => !item.prescriptionOnly)
        .fold<double>(0, (sum, item) => sum + item.lineTotal);
    final channelingFee = PrescriptionStore.consultationFee;
    final grandTotal = medicineTotal + channelingFee;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F7FC),
        dividerColor: Colors.transparent,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: Color(0xFF0F766E),
              width: 1.5,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF4F7FC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF075E54),
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: Text(
            _isEditMode ? 'Edit Prescription' : 'Create Prescription',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.science_outlined),
              tooltip: 'Lab investigations',
              onPressed: _openLabInvestigations,
            ),
            IconButton(
              icon: const Icon(Icons.folder_copy_outlined),
              tooltip: 'Templates',
              onPressed: _openTemplateScreen,
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'clear') _clearForm();
                if (value == 'template') _saveAsTemplate();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'template',
                  child: Row(
                    children: [
                      Icon(Icons.star_outline),
                      SizedBox(width: 10),
                      Text('Save as template'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Clear form', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _buildPrescriptionHeader(items.length)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  16,
                  14,
                  items.isEmpty ? 28 : 120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _premiumCard(child: _buildPatientDetailsSection()),
                    const SizedBox(height: 14),
                    _premiumCard(child: _buildSmartMedicalAssist()),
                    const SizedBox(height: 14),
                    _premiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeading(
                            icon: Icons.medical_services_outlined,
                            title: 'Clinical Assessment',
                            subtitle: 'Complaints, diagnosis and visit notes',
                            color: const Color(0xFF0F766E),
                          ),
                          const SizedBox(height: 15),
                          _buildSmartClinicalField(
                            title: 'Complaint',
                            hintText: 'Type or select complaints',
                            controller: _complaintController,
                            searchController: _complaintSearchController,
                            options: _complaintOptions,
                            selectedChips: _selectedComplaintChips,
                            onChipSelected: _selectComplaintChip,
                            icon: Icons.sick_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildSmartClinicalField(
                            title: 'Diagnosis',
                            hintText: 'Type or select diagnoses',
                            controller: _diagnosisController,
                            searchController: _diagnosisSearchController,
                            options: _diagnosisOptions,
                            selectedChips: _selectedDiagnosisChips,
                            onChipSelected: _selectDiagnosisChip,
                            icon: Icons.medical_information_outlined,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _visitNotesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Visit Notes (optional)',
                              hintText: 'Add clinical observations or advice',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                            onChanged: (_) => _savePatientDetailsToStore(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _premiumCard(
                      child: Column(
                        children: [
                          _sectionHeading(
                            icon: Icons.medication_outlined,
                            title: 'Medicines',
                            subtitle: items.isEmpty
                                ? 'No medicines added yet'
                                : '${items.length} medicine${items.length == 1 ? '' : 's'} added',
                            trailing: FilledButton.icon(
                              onPressed: _openMedicinesScreen,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFD),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(
                                  color: const Color(0xFFDDE5F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.medication_liquid_outlined,
                                    size: 42,
                                    color: Color(0xFF9AA8BC),
                                  ),
                                  const SizedBox(height: 9),
                                  const Text(
                                    'Build the prescription',
                                    style: TextStyle(
                                      color: Color(0xFF14213D),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Add the first medicine to continue',
                                    style: TextStyle(
                                      color: Color(0xFF718096),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _openMedicinesScreen,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Medicine'),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...items.asMap().entries.map(
                                  (entry) => _buildMedicineCard(
                                    entry.key,
                                    entry.value,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _premiumCard(child: _buildVisitDetailsSection()),
                    const SizedBox(height: 14),
                    _premiumCard(child: _buildFollowUpSection()),
                    const SizedBox(height: 14),
                    _premiumCard(child: _buildBillingSection()),
                    if (_favoriteTemplates.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildFavoriteTemplatesSection(),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0F766E).withOpacity(0.10),
                            const Color(0xFF22A06B).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF0F766E).withOpacity(0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Medicine total', medicineTotal),
                          const SizedBox(height: 8),
                          _summaryRow('Channeling fee', channelingFee),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 9),
                            child: Divider(height: 1),
                          ),
                          _summaryRow(
                            'Grand total',
                            grandTotal,
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: items.isEmpty || keyboardVisible
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: Color(0xFFE3E9F2)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 18,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _prescriptionSaved ? _openPrintPreview : null,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _savePrescriptionToDb,
                          icon: Icon(
                            _isEditMode ? Icons.update : Icons.save_outlined,
                          ),
                          label: Text(
                            _isEditMode
                                ? 'Update Prescription'
                                : 'Save Prescription',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double amount, {
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color:
                  emphasize ? const Color(0xFF14213D) : const Color(0xFF5F6B7A),
              fontSize: emphasize ? 16 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color:
                emphasize ? const Color(0xFF0F766E) : const Color(0xFF14213D),
            fontSize: emphasize ? 18 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
