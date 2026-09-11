import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../data/prescription_store.dart';
import '../models/prescription_item.dart';
import 'prescription_list_screen.dart';
import 'print_preview_screen.dart';
import '../../lab/screens/patient_lab_reports_screen.dart';

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
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int? _doctorId;
  int _totalVisits = 0;
  int _filteredVisits = 0;
  int _offset = 0;
  final TextEditingController _visitSearchController = TextEditingController();
  Timer? _searchDebounce;
  DateTimeRange? _visitDateRange;
  bool _oldestFirst = false;
  int _loadGeneration = 0;
  static const int _limit = 30;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _visitSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreVisits();
    }
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
    final generation = ++_loadGeneration;

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

      final prescriptions = await DatabaseHelper.instance
          .getFilteredPrescriptionsByPatientAndDoctorPaged(
        widget.patientId,
        _doctorId!,
        query: _visitSearchController.text,
        dateFrom: _dateKey(_visitDateRange?.start),
        dateTo: _dateKey(_visitDateRange?.end),
        oldestFirst: _oldestFirst,
        limit: _limit,
        offset: 0,
      );
      final totalVisits = await DatabaseHelper.instance
          .countPrescriptionsByPatientAndDoctor(widget.patientId, _doctorId!);
      final filteredVisits = await DatabaseHelper.instance
          .countFilteredPrescriptionsByPatientAndDoctor(
        widget.patientId,
        _doctorId!,
        query: _visitSearchController.text,
        dateFrom: _dateKey(_visitDateRange?.start),
        dateTo: _dateKey(_visitDateRange?.end),
      );
      final latest = await DatabaseHelper.instance
          .getFilteredPrescriptionsByPatientAndDoctorPaged(
        widget.patientId,
        _doctorId!,
        limit: 1,
        offset: 0,
      );
      Map<String, dynamic>? lastPrescription;
      List<Map<String, dynamic>> lastMedicines = [];

      if (latest.isNotEmpty) {
        lastPrescription = latest.first;

        final lastId = lastPrescription['id'] as int;

        lastMedicines =
            await DatabaseHelper.instance.getLastPrescriptionMedicines(lastId);
      }

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _patient = patient;
        _prescriptions = prescriptions;
        _totalVisits = totalVisits;
        _filteredVisits = filteredVisits;
        _offset = prescriptions.length;
        _hasMore = prescriptions.length < filteredVisits;
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

  Future<void> _loadMoreVisits() async {
    if (_doctorId == null || !_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await DatabaseHelper.instance
          .getFilteredPrescriptionsByPatientAndDoctorPaged(
        widget.patientId,
        _doctorId!,
        query: _visitSearchController.text,
        dateFrom: _dateKey(_visitDateRange?.start),
        dateTo: _dateKey(_visitDateRange?.end),
        oldestFirst: _oldestFirst,
        limit: _limit,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _prescriptions.addAll(data);
        _offset += data.length;
        _hasMore = _offset < _filteredVisits;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load more visits: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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

  String? _dateKey(DateTime? value) =>
      value == null ? null : DateFormat('yyyy-MM-dd').format(value);

  String _friendlyDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('dd MMM yyyy').format(parsed);
  }

  void _onVisitSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_loadProfile()),
    );
  }

  Future<void> _pickVisitDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _visitDateRange,
    );
    if (range == null || !mounted) return;
    setState(() => _visitDateRange = range);
    await _loadProfile();
  }

  void _clearVisitFilters() {
    _visitSearchController.clear();
    setState(() {
      _visitDateRange = null;
      _oldestFirst = false;
    });
    unawaited(_loadProfile());
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
            color: const Color(0xFF0F766E).withValues(alpha: 0.18),
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
              _chip('Visits', '$_totalVisits'),
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

    final date = _friendlyDate(_lastPrescription!['prescription_date']);

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

  Widget _buildLabReportsCard() {
    final serverId = int.tryParse(
        (_patient?['server_id'] ?? _patient?['serverId'] ?? '').toString());
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
            backgroundColor: Color(0xFFE6FFFB),
            child: Icon(Icons.science_outlined, color: Color(0xFF0F766E))),
        title: const Text('Laboratory Reports',
            style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(serverId == null
            ? 'Sync this patient to view cloud lab reports'
            : 'View uploaded reports and mark them reviewed'),
        trailing: const Icon(Icons.chevron_right),
        enabled: serverId != null,
        onTap: serverId == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PatientLabReportsScreen(
                        serverPatientId: serverId,
                        patientName: _getPatientName()))),
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final rxNo = (item['prescription_no'] ?? '').toString();
    final date = _friendlyDate(item['prescription_date']);
    final diagnosis = (item['diagnosis'] ?? '').toString();
    final complaint = (item['complaint'] ?? '').toString();
    final notes = (item['visit_notes'] ?? '').toString();
    final syncStatus = (item['sync_status'] ?? '').toString();
    final followUpDate = _friendlyDate(item['follow_up_date']);
    final followUpNote = (item['follow_up_note'] ?? '').toString();
    final followUpStatus = (item['follow_up_status'] ?? '').toString();

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
    final medicines = _parseItemsText((item['items_text'] ?? '').toString());

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
          'Date: $date${diagnosis.isEmpty ? '' : '  •  $diagnosis'}',
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailSection('Clinical Assessment', [
                  if (complaint.isNotEmpty) _detailRow('Complaint', complaint),
                  if (diagnosis.isNotEmpty) _detailRow('Diagnosis', diagnosis),
                  if (notes.isNotEmpty) _detailRow('Visit Notes', notes),
                  if (complaint.isEmpty && diagnosis.isEmpty && notes.isEmpty)
                    const Text('No clinical notes recorded.',
                        style: TextStyle(color: Color(0xFF64748B))),
                ]),
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
                if (medicines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailSection(
                    'Medicines (${medicines.length})',
                    medicines.asMap().entries.map((entry) {
                      final medicine = entry.value;
                      final directions = [
                        medicine.dosage,
                        medicine.frequency,
                        medicine.duration
                      ].where((x) => x.trim().isNotEmpty).join(' • ');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${entry.key + 1}. ${medicine.medicineName}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              if (directions.isNotEmpty)
                                Text(directions,
                                    style: const TextStyle(
                                        color: Color(0xFF475569))),
                              if (medicine.instructions.trim().isNotEmpty)
                                Text('Instructions: ${medicine.instructions}',
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12)),
                            ]),
                      );
                    }).toList(),
                  ),
                ],
                if (followUpDate != '-' || followUpNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailSection('Follow-up', [
                    if (followUpDate != '-') _detailRow('Date', followUpDate),
                    if (followUpNote.isNotEmpty)
                      _detailRow('Note', followUpNote),
                    if (followUpStatus.isNotEmpty)
                      _detailRow('Status', followUpStatus),
                  ]),
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

  Widget _detailSection(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
            text: TextSpan(
                style: const TextStyle(color: Color(0xFF334155), height: 1.4),
                children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: value),
            ])),
      );

  Widget _buildVisitFilters() {
    final dateLabel = _visitDateRange == null
        ? 'Date range'
        : '${_friendlyDate(_visitDateRange!.start)} – ${_friendlyDate(_visitDateRange!.end)}';
    final active = _visitSearchController.text.trim().isNotEmpty ||
        _visitDateRange != null ||
        _oldestFirst;
    return Column(children: [
      TextField(
        controller: _visitSearchController,
        onChanged: _onVisitSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search Rx, diagnosis, complaint or medicine',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _visitSearchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _visitSearchController.clear();
                    unawaited(_loadProfile());
                  },
                  icon: const Icon(Icons.close_rounded)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      ),
      const SizedBox(height: 9),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: _pickVisitDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(dateLabel, overflow: TextOverflow.ellipsis))),
        const SizedBox(width: 8),
        PopupMenuButton<bool>(
          initialValue: _oldestFirst,
          onSelected: (value) {
            setState(() => _oldestFirst = value);
            unawaited(_loadProfile());
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: false, child: Text('Newest first')),
            PopupMenuItem(value: true, child: Text('Oldest first'))
          ],
          child: const Padding(
              padding: EdgeInsets.all(10), child: Icon(Icons.sort_rounded)),
        ),
        if (active)
          IconButton(
              tooltip: 'Clear filters',
              onPressed: _clearVisitFilters,
              icon: const Icon(Icons.filter_alt_off_outlined)),
      ]),
      Align(
          alignment: Alignment.centerLeft,
          child: Text('$_filteredVisits of $_totalVisits visit(s)',
              style: const TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
    ]);
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
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _buildCompactHeader(),
                  const SizedBox(height: 12),
                  _buildCompactMedicalAlerts(),
                  const SizedBox(height: 12),
                  _buildPatientTimelineCard(),
                  const SizedBox(height: 12),
                  _buildLabReportsCard(),
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
                  _buildVisitFilters(),
                  const SizedBox(height: 12),
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
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}
