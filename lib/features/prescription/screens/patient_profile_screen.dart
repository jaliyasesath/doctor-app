import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../data/prescription_store.dart';
import '../models/prescription_item.dart';
import 'prescription_list_screen.dart';
import 'print_preview_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final int patientId;

  const PatientProfileScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _prescriptions = [];
  Map<String, dynamic>? _lastPrescription;
  List<Map<String, dynamic>> _lastMedicines = [];

  bool _isLoading = true;
  int? _doctorId;

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
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_doctorId == null) return;

    setState(() => _isLoading = true);

    try {
      final patient = await DatabaseHelper.instance.getPatientById(
        widget.patientId,
      );

      if (patient == null || patient['doctor_id'] != _doctorId) {
        if (!mounted) return;

        setState(() {
          _patient = null;
          _prescriptions = [];
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient not found for this doctor')),
        );
        return;
      }

      final prescriptions =
          await DatabaseHelper.instance.getPrescriptionsByPatientAndDoctor(
        widget.patientId,
        _doctorId!,
      );
      Map<String, dynamic>? lastPrescription;
      List<Map<String, dynamic>> lastMedicines = [];

      if (prescriptions.isNotEmpty) {
        lastPrescription = prescriptions.first;

        final lastId = lastPrescription['id'] as int;

        lastMedicines =
            await DatabaseHelper.instance.getLastPrescriptionMedicines(lastId);
      }

      if (!mounted) return;

      setState(() {
        _patient = patient;
        _prescriptions = prescriptions;
        _lastPrescription = lastPrescription;
        _lastMedicines = lastMedicines;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    }
  }

  String _getPatientName() {
    return (_patient?['patient_name'] ?? _patient?['patientName'] ?? '')
        .toString();
  }

  String _getPatientAge() {
    return (_patient?['patient_age'] ??
            _patient?['patientAge'] ??
            _patient?['age'] ??
            '')
        .toString();
  }

  String _getPatientGender() {
    return (_patient?['patient_gender'] ??
            _patient?['patientGender'] ??
            _patient?['gender'] ??
            '')
        .toString();
  }

  String _getPatientPhone() {
    return (_patient?['phone_number'] ?? _patient?['phoneNumber'] ?? '')
        .toString();
  }

  String _getPatientAddress() {
    return (_patient?['address'] ?? '').toString();
  }

  String _getPatientNotes() {
    return (_patient?['notes'] ?? '').toString();
  }

  String _getBloodGroup() {
    return (_patient?['blood_group'] ?? '').toString();
  }

  String _getAllergies() {
    return (_patient?['allergies'] ?? '').toString();
  }

  String _getChronicDiseases() {
    return (_patient?['chronic_diseases'] ?? '').toString();
  }

  String _getImportantAlerts() {
    return (_patient?['important_alerts'] ?? '').toString();
  }

  List<PrescriptionItem> _parseItemsText(String itemsText) {
    if (itemsText.trim().isEmpty) return [];

    return itemsText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();

      return PrescriptionItem(
        medicineName: parts.isNotEmpty ? parts[0] : '',
        dosage: parts.length > 1 ? parts[1] : '',
        frequency: parts.length > 2 ? parts[2] : '',
        duration: parts.length > 3 ? parts[3] : '',
        instructions: parts.length > 4 ? parts[4] : '',
      );
    }).toList();
  }

  void _openPrescription(Map<String, dynamic> item) {
    final items = _parseItemsText((item['items_text'] ?? '').toString());

    PrescriptionStore.setPatientDetails(
      name: _getPatientName(),
      age: _getPatientAge(),
      gender: _getPatientGender(),
      phoneNumber: _getPatientPhone(),
      address: _getPatientAddress(),
      notes: _getPatientNotes(),
    );

    PrescriptionStore.setClinicalDetails(
      complaintText: (item['complaint'] ?? '').toString(),
      diagnosisText: (item['diagnosis'] ?? '').toString(),
      visitNotesText: (item['visit_notes'] ?? '').toString(),
    );

    PrescriptionStore.setItems(items);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          passedRxNo: (item['prescription_no'] ?? '').toString(),
          passedDate: (item['prescription_date'] ?? '').toString(),
        ),
      ),
    );
  }

  void _repeatPrescription(Map<String, dynamic> item) {
    final items = _parseItemsText((item['items_text'] ?? '').toString());

    PrescriptionStore.setPatientDetails(
      name: _getPatientName(),
      age: _getPatientAge(),
      gender: _getPatientGender(),
      phoneNumber: _getPatientPhone(),
      address: _getPatientAddress(),
      notes: _getPatientNotes(),
    );

    PrescriptionStore.setClinicalDetails(
      complaintText: (item['complaint'] ?? '').toString(),
      diagnosisText: (item['diagnosis'] ?? '').toString(),
      visitNotesText: (item['visit_notes'] ?? '').toString(),
    );

    PrescriptionStore.setItems(items);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrescriptionListScreen(),
      ),
    );
  }

  Widget _chip(String label, String value, {Color? color}) {
    if (value.trim().isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _vitalChip(String label, String value) {
    return _chip(label, value);
  }

  Widget _buildCompactHeader() {
    final name = _getPatientName();
    final age = _getPatientAge();
    final gender = _getPatientGender();
    final phone = _getPatientPhone();
    final address = _getPatientAddress();
    final blood = _getBloodGroup();
    final notes = _getPatientNotes();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? 'Patient' : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${age.isEmpty ? '-' : '$age yrs'} • ${gender.isEmpty ? '-' : gender}',
            style: const TextStyle(
              color: Color(0xFFCCFBF1),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Visits', '${_prescriptions.length}'),
              if (phone.isNotEmpty) _chip('Phone', phone),
              if (blood.isNotEmpty) _chip('Blood', blood),
              if (address.isNotEmpty) _chip('Address', address),
              if (notes.isNotEmpty) _chip('Notes', notes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMedicalAlerts() {
    final allergies = _getAllergies();
    final diseases = _getChronicDiseases();
    final alerts = _getImportantAlerts();

    if (allergies.isEmpty && diseases.isEmpty && alerts.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Medical Alerts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (allergies.isNotEmpty)
                _chip('Allergy', allergies, color: Colors.red.shade50),
              if (diseases.isNotEmpty)
                _chip('Chronic', diseases, color: Colors.orange.shade100),
              if (alerts.isNotEmpty)
                _chip('Alert', alerts, color: Colors.yellow.shade100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientTimelineCard() {
    if (_lastPrescription == null) {
      return const SizedBox();
    }

    final diagnosis = (_lastPrescription!['diagnosis'] ?? '').toString();

    final bp =
        (_lastPrescription!['bp'] ?? _lastPrescription!['blood_pressure'] ?? '')
            .toString();

    final date = (_lastPrescription!['prescription_date'] ?? '').toString();

    final medicineNames = _lastMedicines
        .map(
          (e) => e['medicine_name']?.toString() ?? '',
        )
        .where((e) => e.isNotEmpty)
        .take(3)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCCFBF1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.timeline,
                color: Color(0xFF0F766E),
              ),
              SizedBox(width: 8),
              Text(
                'Patient Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _chip('Last Visit', date),
          if (diagnosis.isNotEmpty) ...[
            const SizedBox(height: 8),
            _chip(
              'Previous Diagnosis',
              diagnosis,
            ),
          ],
          if (bp.isNotEmpty) ...[
            const SizedBox(height: 8),
            _chip('Last BP', bp),
          ],
          if (medicineNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            _chip(
              'Last Medicines',
              medicineNames,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final rxNo = (item['prescription_no'] ?? '').toString();
    final date = (item['prescription_date'] ?? '').toString();
    final diagnosis = (item['diagnosis'] ?? '').toString();
    final complaint = (item['complaint'] ?? '').toString();
    final notes = (item['visit_notes'] ?? '').toString();
    final syncStatus = (item['sync_status'] ?? '').toString();

    final bp = (item['bp'] ?? item['blood_pressure'] ?? '').toString();
    final weight = (item['weight'] ?? '').toString();
    final pulse = (item['pulse'] ?? '').toString();
    final temperature = (item['temperature'] ?? item['temp'] ?? '').toString();
    final spo2 = (item['spo2'] ?? item['sp_o2'] ?? '').toString();

    final hasVitals = bp.isNotEmpty ||
        weight.isNotEmpty ||
        pulse.isNotEmpty ||
        temperature.isNotEmpty ||
        spo2.isNotEmpty;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE6FFFB),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: Color(0xFF0F766E),
          ),
        ),
        title: Text(
          'Rx: ${rxNo.isEmpty ? id.toString() : rxNo}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          date.isEmpty ? 'Date: -' : 'Date: $date',
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (complaint.isNotEmpty) Text('Complaint: $complaint'),
                if (diagnosis.isNotEmpty) Text('Diagnosis: $diagnosis'),
                if (notes.isNotEmpty) Text('Visit Notes: $notes'),
                if (hasVitals) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Visit Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _vitalChip('BP', bp),
                      _vitalChip('Weight', weight),
                      _vitalChip('Pulse', pulse),
                      _vitalChip('Temp', temperature),
                      _vitalChip('SpO2', spo2),
                    ],
                  ),
                ],
                if (syncStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sync: $syncStatus',
                    style: TextStyle(
                      color:
                          syncStatus == 'synced' ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('Open'),
                        onPressed: () => _openPrescription(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.repeat),
                        label: const Text('Repeat'),
                        onPressed: () => _repeatPrescription(item),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final patientName =
        _patient == null ? 'Patient Profile' : _getPatientName();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        surfaceTintColor: Colors.transparent,
        title: Text(patientName.isEmpty ? 'Patient Profile' : patientName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _buildCompactHeader(),
                  const SizedBox(height: 12),
                  _buildCompactMedicalAlerts(),
                  const SizedBox(height: 12),
                  _buildPatientTimelineCard(),
                  const SizedBox(height: 16),
                  const Text(
                    'Previous Visits',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_prescriptions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(30),
                      alignment: Alignment.center,
                      child: const Text('No previous visits found'),
                    )
                  else
                    Column(
                      children: _prescriptions
                          .map((item) => _buildPrescriptionCard(item))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
