import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../patient/data/api_patient_service.dart';
import '../../auth/data/doctor_session.dart';
import '../../sync/services/network_service.dart';
import '../../sync/services/sync_service.dart';
import '../../template/data/template_service.dart';
import '../../template/models/template_model.dart';
import '../../template/screens/template_list_screen.dart';
import '../data/prescription_store.dart';
import '../models/prescription_item.dart';
import '../widgets/smart_chips_section.dart';
import 'print_preview_screen.dart';
import '../../notifications/services/local_notification_service.dart';

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
  bool _prescriptionSaved = false;
  final ApiPatientService _patientApi = ApiPatientService();

  String? _selectedComplaintChip;
  String? _selectedDiagnosisChip;

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
  text: widget.patientPhone ??
      PrescriptionStore.patientPhoneNumber,
);
    _patientAddressController = TextEditingController(
  text: widget.patientAddress ??
      PrescriptionStore.patientAddress,
);
    _patientNotesController =
        TextEditingController(text: PrescriptionStore.patientNotes);

    _complaintController =
        TextEditingController(text: PrescriptionStore.complaint);
    _diagnosisController =
        TextEditingController(text: PrescriptionStore.diagnosis);
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

  final complaintChips =
      await DatabaseHelper.instance.getClinicalChips(
    doctorId: doctorId,
    category: 'complaint',
  );

  final diagnosisChips =
      await DatabaseHelper.instance.getClinicalChips(
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

    await DatabaseHelper.instance.insertCustomInstruction({
      'doctor_id': doctorId,
      'instruction_text': value,
    });

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
    _visitNotesController.dispose();

    _bloodPressureController.dispose();
    _weightController.dispose();
    _pulseController.dispose();
    _temperatureController.dispose();
    _spo2Controller.dispose();

    super.dispose();
  }

  void _syncSelectedClinicalChips() {
    _selectedComplaintChip =
        _findExactMatch(_complaintController.text, _complaintOptions);
    _selectedDiagnosisChip =
        _findExactMatch(_diagnosisController.text, _diagnosisOptions);
  }

  String? _findExactMatch(String value, List<String> options) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final option in options) {
      if (option.toLowerCase() == normalized) return option;
    }
    return null;
  }

  List<String> _getSuggestions(String value, List<String> options) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    return options
        .where((option) => option.toLowerCase().contains(normalized))
        .toList();
  }

  void _handleComplaintChanged() {
    final exact = _findExactMatch(_complaintController.text, _complaintOptions);

    if (_selectedComplaintChip != exact) {
      setState(() => _selectedComplaintChip = exact);
    }

    _savePatientDetailsToStore();
  }

  void _handleDiagnosisChanged() {
    final exact = _findExactMatch(_diagnosisController.text, _diagnosisOptions);

    if (_selectedDiagnosisChip != exact) {
      setState(() => _selectedDiagnosisChip = exact);
    }

    _savePatientDetailsToStore();
  }

  void _selectComplaintChip(String value) {
    setState(() {
      _selectedComplaintChip = value;
      _complaintController.text = value;
      _complaintController.selection = TextSelection.fromPosition(
        TextPosition(offset: _complaintController.text.length),
      );
    });

    _savePatientDetailsToStore();
  }

  void _selectDiagnosisChip(String value) {
    setState(() {
      _selectedDiagnosisChip = value;
      _diagnosisController.text = value;
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

  Future<bool> _checkAllergyBeforeAdd(Map<String, dynamic> medicine) async {
    final drugGroup =
        medicine['drug_group']?.toString().trim().toLowerCase() ?? '';

    if (drugGroup.isEmpty) return true;

    final allergyText = _patientAllergyText();

    if (!allergyText.contains(drugGroup)) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Allergy Warning'),
        content: Text(
          'Patient allergy contains "$drugGroup".\n\n'
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

  List<Map<String, dynamic>> filteredMedicines =
      List.from(masterMedicines);

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

  final durationController =
    TextEditingController(text: '5');
    final quantityController =
    TextEditingController(text: '1');

String selectedDurationUnit = 'Days';

  final initialDoseForm =
      selected?['dose_form']?.toString() ?? '';

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
          final instructionValue =
              instructionsController.text.trim();

          final instructionSuggestions =
              _allInstructionSuggestions();

          final dropdownValue =
              instructionSuggestions.contains(
                      instructionValue)
                  ? instructionValue
                  : null;

          return AlertDialog(
            title: const Text('Add Medicine'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Medicine',
                        hintText:
                            'Type medicine / group / brand',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final q =
                            value.trim().toLowerCase();

                        setDialogState(() {
                          filteredMedicines =
                              masterMedicines.where((m) {
                            final name =
                                m['medicine_name']
                                        ?.toString()
                                        .toLowerCase() ??
                                    '';

                            final generic =
                                m['generic_name']
                                        ?.toString()
                                        .toLowerCase() ??
                                    '';

                            final brand =
                                m['brand_name']
                                        ?.toString()
                                        .toLowerCase() ??
                                    '';

                            final group =
                                m['drug_group']
                                        ?.toString()
                                        .toLowerCase() ??
                                    '';

                            final strength =
                                m['strength']
                                        ?.toString()
                                        .toLowerCase() ??
                                    '';

                            return name.contains(q) ||
                                generic.contains(q) ||
                                brand.contains(q) ||
                                group.contains(q) ||
                                strength.contains(q);
                          }).toList();

                          filteredMedicines.sort((a, b) {
                            final favA =
                                a['is_favorite'] ?? 0;

                            final favB =
                                b['is_favorite'] ?? 0;

                            return favB.compareTo(favA);
                          });
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.black12),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: filteredMedicines.isEmpty
                          ? const Center(
                              child:
                                  Text('No medicine found'),
                            )
                          : ListView.builder(
                              itemCount:
                                  filteredMedicines.length,
                              itemBuilder:
                                  (context, index) {
                                final med =
                                    filteredMedicines[index];

                                final isSelected =
                                    selected?['id'] ==
                                        med['id'];

                                final isFav =
                                    (med['is_favorite'] ??
                                            0) ==
                                        1;

                                final name =
                                    med['medicine_name']
                                            ?.toString() ??
                                        '';

                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor:
                                      Colors.blue
                                          .withOpacity(0.12),
                                  leading: Icon(
                                    isFav
                                        ? Icons.star
                                        : Icons
                                            .medication_outlined,
                                    color: isFav
                                        ? Colors.amber
                                        : Colors.blue,
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight
                                                  .bold
                                              : FontWeight
                                                  .normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${med['strength'] ?? ''} ${med['drug_group'] ?? ''}',
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color:
                                              Colors.green,
                                        )
                                      : null,
                                  onTap: () {
                                    setDialogState(() {
                                      selected = med;

                                      dosageController.text =
                                          med['strength']
                                                  ?.toString() ??
                                              '';

                                      final doseForm =
                                          med['dose_form']
                                                  ?.toString() ??
                                              '';

                                      final defaultInstruction =
                                          defaultInstructions[
                                                  doseForm] ??
                                              '';

                                      instructionsController
                                              .text =
                                          defaultInstruction;
                                    });
                                  },
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'Example: 500mg',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'OD',
                          child:
                              Text('OD - Once Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'BD',
                          child:
                              Text('BD - Twice Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'TDS',
                          child: Text(
                              'TDS - Three Times Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'QID',
                          child: Text(
                              'QID - Four Times Daily'),
                        ),
                        DropdownMenuItem(
                          value: 'HS',
                          child: Text('HS - Night'),
                        ),
                        DropdownMenuItem(
                          value: 'SOS',
                          child:
                              Text('SOS - When Needed'),
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
          DropdownMenuItem(value: 'Days', child: Text('Days')),
          DropdownMenuItem(value: 'Weeks', child: Text('Weeks')),
          DropdownMenuItem(value: 'Months', child: Text('Months')),
          DropdownMenuItem(value: 'Years', child: Text('Years')),
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
                      controller:
                          instructionsController,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(
                        labelText: 'Instructions',
                        hintText:
                            'After meals / Before meals',
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
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text('Add'),
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

  final canAdd =
      await _checkAllergyBeforeAdd(selected!);

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
        medicineName:
            selected!['medicine_name'].toString(),
        dosage: dosageController.text.trim(),
        frequency: selectedFrequency,
        duration: _buildDurationValue(
  durationController.text,
  selectedDurationUnit,
),
        instructions:
            instructionsController.text.trim(),
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
        await DatabaseHelper.instance.updatePatient(localPatientId, patientData);
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
        'follow_up_date':
    _followUpDate
        ?.toIso8601String(),

'follow_up_note':
    _followUpNoteController
        .text
        .trim()
        .isEmpty
    ? null
    : _followUpNoteController
        .text
        .trim(),

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

final itemRows = items.map((item) {
  return {
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
      _selectedComplaintChip = null;
      _selectedDiagnosisChip = null;

      selectedAllergies = [];
      selectedDiseases = [];

      selectedMedicine = null;
      _prescriptionSaved = false;
      _currentRxNo = null;
      _currentPatientId = null;
    });
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

    await TemplateService.saveTemplate(template);

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
  controller.text = cleanValue;

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

  final isDefault =
      title == 'Complaint'
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

    if (title == 'Complaint' &&
        _selectedComplaintChip == value) {
      _selectedComplaintChip = null;
      _complaintController.clear();
    }

    if (title == 'Diagnosis' &&
        _selectedDiagnosisChip == value) {
      _selectedDiagnosisChip = null;
      _diagnosisController.clear();
    }
  });

  _savePatientDetailsToStore();
}

 Widget _buildSmartClinicalField({
  required String title,
  required String hintText,
  required TextEditingController controller,
  required List<String> options,
  required String? selectedChip,
  required ValueChanged<String> onChipSelected,
  IconData? icon,
}) {
  final suggestions = _getSuggestions(controller.text, options);

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
              Icon(icon, size: 18, color: Colors.blueGrey),
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
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.trim().isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                      _savePatientDetailsToStore();
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedChip == option;

            return GestureDetector(
  onLongPress: () {
    _deleteClinicalOption(
      title: title,
      value: option,
      options: options,
    );
  },
  child: ChoiceChip(
    label: Text(option),
    selected: isSelected,
    onSelected: (_) => onChipSelected(option),
  ),
);
          }).toList(),
        ),
        if (controller.text.isNotEmpty && suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((option) {
              return ActionChip(
                label: Text(option),
                onPressed: () => onChipSelected(option),
              );
            }).toList(),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildSmartMedicalAssist() {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'Smart Medical Assist',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text(
        selectedAllergies.isEmpty && selectedDiseases.isEmpty
            ? 'Tap to add allergies and chronic diseases'
            : 'Allergies: ${selectedAllergies.length} | Diseases: ${selectedDiseases.length}',
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

            final dia =
                current.length > 1 ? current[1] : '';

            _bloodPressureController.text =
                '$value/$dia';
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

            final sys =
                current.isNotEmpty ? current[0] : '';

            _bloodPressureController.text =
                '$sys/$value';
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
      _selectedComplaintChip = null;
      _selectedDiagnosisChip = null;

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
        Icon(Icons.person_outline, color: Colors.blue),
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

  @override
Widget build(BuildContext context) {
  final items = PrescriptionStore.items;

  final medicineTotal = items
      .where((e) => !e.prescriptionOnly)
      .fold<double>(0, (sum, e) => sum + e.lineTotal);

  final channelingFee = PrescriptionStore.consultationFee;

  final grandTotal = medicineTotal + channelingFee;

    return Scaffold(
  resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Prescription' : 'Prescription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_copy_outlined),
            tooltip: 'Templates',
            onPressed: _openTemplateScreen,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Medicine',
            onPressed: _openMedicinesScreen,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear All',
            onPressed: _clearForm,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
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
                      if (_currentRxNo != null &&
                          _currentRxNo!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Rx: $_currentRxNo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      _buildPatientDetailsSection(),
const SizedBox(height: 14),

_buildSmartMedicalAssist(),
const SizedBox(height: 14),

_buildVisitDetailsSection(),
                      const SizedBox(height: 14),
_buildFollowUpSection(),
const SizedBox(height: 14),

_buildBillingSection(),
const SizedBox(height: 14),

_buildFavoriteTemplatesSection(),
const SizedBox(height: 14),

_buildSmartClinicalField(
                        title: 'Complaint',
                        hintText: 'Type or select complaint',
                        controller: _complaintController,
                        options: _complaintOptions,
                        selectedChip: _selectedComplaintChip,
                        onChipSelected: _selectComplaintChip,
                        icon: Icons.sick_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildSmartClinicalField(
                        title: 'Diagnosis',
                        hintText: 'Type or select diagnosis',
                        controller: _diagnosisController,
                        options: _diagnosisOptions,
                        selectedChip: _selectedDiagnosisChip,
                        onChipSelected: _selectDiagnosisChip,
                        icon: Icons.medical_information_outlined,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _visitNotesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Visit Notes (optional)',
                          hintText: 'Extra notes if needed',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) => _savePatientDetailsToStore(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openMedicinesScreen,
                              icon: const Icon(Icons.medication_outlined),
                              label: const Text('Add Medicine'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saveAsTemplate,
                              icon: const Icon(Icons.star_outline),
                              label: const Text('Save Template'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.green.withOpacity(0.08),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.green.withOpacity(0.25)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Bill Summary',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 8),
      Text('Medicine Total: Rs. ${medicineTotal.toStringAsFixed(2)}'),
      Text('Channeling Fee: Rs. ${channelingFee.toStringAsFixed(2)}'),
      const Divider(),
      Text(
        'Grand Total: Rs. ${grandTotal.toStringAsFixed(2)}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    ],
  ),
),
                
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No medicines added'),
                    ),
                  )
                else
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                      child: Row(
                        children: [
                          const Icon(Icons.medication, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      item.medicineName,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),

    if (item.prescriptionOnly) ...[
      const SizedBox(height: 4),

      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Prescription Only',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],

    const SizedBox(height: 4),

    Text(
      '${item.dosage} • ${item.frequency} • ${item.duration}',
      style: const TextStyle(
        color: Colors.black54,
      ),
    ),
    if (!item.prescriptionOnly) ...[
  const SizedBox(height: 4),
  Text(
    'Qty: ${item.quantity.toStringAsFixed(0)} • '
    'Unit: Rs. ${item.unitPrice.toStringAsFixed(2)} • '
    'Total: Rs. ${item.lineTotal.toStringAsFixed(2)}',
    style: const TextStyle(
      color: Colors.green,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  ),
],

    if (item.instructions.isNotEmpty) ...[
      const SizedBox(height: 4),

      Text(
        item.instructions,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontSize: 13,
        ),
      ),
    ],
  ],
)
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _editMedicineItem(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() => items.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: items.isEmpty
    ? null
    : Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0
              ? MediaQuery.of(context).viewInsets.bottom + 12
              : 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: Icon(_isEditMode ? Icons.update : Icons.save),
                  label: Text(_isEditMode ? 'Update Prescription' : 'Save'),
                  onPressed: _savePrescriptionToDb,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print Preview'),
                 onPressed:
    _prescriptionSaved
        ? _openPrintPreview
        : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}