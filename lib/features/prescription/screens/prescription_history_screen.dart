import 'package:flutter/material.dart';
import 'dart:async';
import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../data/prescription_store.dart';
import '../models/prescription_item.dart';
import 'print_preview_screen.dart';
import '../../reception/screens/reception_prescription_edit_screen.dart';

class PrescriptionHistoryScreen extends StatefulWidget {

  final bool receptionMode;

  const PrescriptionHistoryScreen({
    super.key,
    this.receptionMode = false,
  });

  @override
  State<PrescriptionHistoryScreen> createState() =>
      _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState
    extends State<PrescriptionHistoryScreen> {
  List<Map<String, dynamic>> _prescriptions = [];

bool _isLoading = true;
bool _isLoadingMore = false;
bool _hasMore = true;

int? _doctorId;

final ScrollController _scrollController = ScrollController();
Timer? _refreshTimer;

final int _limit = 30;
int _offset = 0;

  @override
void initState() {
  super.initState();

  _initAndLoad();
  _refreshTimer = Timer.periodic(
  const Duration(seconds: 5),
  (_) {
    _loadPrescriptions();
  },
);

  _scrollController.addListener(() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMorePrescriptions();
    }
  });
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
    await _loadPrescriptions(showLoader: true);
  }

 Future<void> _loadPrescriptions({bool showLoader = false}) async {
  if (_doctorId == null) return;

  if (showLoader && mounted) {
    setState(() {
      _isLoading = true;
    });
  }

  try {
    final data = widget.receptionMode
    ? await DatabaseHelper.instance.getPrescriptions()
    : await DatabaseHelper.instance.getPrescriptionsByDoctorPaged(
        _doctorId!,
        limit: _limit,
        offset: 0,
      );

    if (!mounted) return;

    setState(() {
      _prescriptions = List<Map<String, dynamic>>.from(data);
      _offset = data.length;
      _hasMore = data.length == _limit;
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

Future<void> _loadMorePrescriptions() async {
  if (_doctorId == null || !_hasMore) return;

  setState(() => _isLoadingMore = true);

  try {
    final data =
        await DatabaseHelper.instance.getPrescriptionsByDoctorPaged(
      _doctorId!,
      limit: _limit,
      offset: _offset,
    );
    debugPrint(
  'Loaded more prescriptions: ${data.length}, offset: $_offset',
);

    if (!mounted) return;

    setState(() {
     _prescriptions =
    List<Map<String, dynamic>>.from(_prescriptions)
      ..addAll(data);
      _offset += data.length;
      _hasMore = data.length == _limit;
      _isLoadingMore = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() => _isLoadingMore = false);
  }
}

  Future<void> _delete(int id) async {
    try {
      await DatabaseHelper.instance.deletePrescription(id);
      await _loadPrescriptions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription deleted locally')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _confirmDelete(int id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Prescription'),
          content: const Text(
            'Are you sure you want to delete this prescription?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _delete(id);
    }
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

  void _open(Map<String, dynamic> item) {
    final items = _parseItemsText((item['items_text'] ?? '').toString());

    PrescriptionStore.setPatientDetails(
      name: (item['patient_name'] ?? '').toString(),
      age: (item['patient_age'] ?? '').toString(),
      gender: (item['patient_gender'] ?? '').toString(),
      phoneNumber: '',
      address: '',
      notes: '',
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

  Future<void> _openReceptionEdit(int prescriptionId) async {
  final updated = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => ReceptionPrescriptionEditScreen(
        prescriptionId: prescriptionId,
      ),
    ),
  );

  if (updated == true) {
    await _loadPrescriptions();
  }
}

  Widget _buildCard(Map<String, dynamic> item) {
    final patientName = (item['patient_name'] ?? '').toString();
    final age = (item['patient_age'] ?? '').toString();
    final gender = (item['patient_gender'] ?? '').toString();
    final id = item['id'] as int;
    final rxNo = (item['prescription_no'] ?? '').toString();
    final date = (item['prescription_date'] ?? '').toString();
    final diagnosis = (item['diagnosis'] ?? '').toString();
    final syncStatus = (item['sync_status'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                patientName.isEmpty ? 'Unknown Patient' : patientName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Age: $age'),
                  Text('Gender: $gender'),
                  Text('Local ID: $id'),
                  Text('Rx No: ${rxNo.isEmpty ? '-' : rxNo}'),
                  Text('Date: ${date.isEmpty ? '-' : date}'),
                  if (diagnosis.isNotEmpty) Text('Diagnosis: $diagnosis'),
                  if (syncStatus.isNotEmpty)
                    Text(
                      'Sync: $syncStatus',
                      style: TextStyle(
                        color: syncStatus == 'synced'
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Open'),
                    onPressed: () => _open(item),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: widget.receptionMode
    ? () => _openReceptionEdit(id)
    : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit feature will be connected next'),
          ),
        );
      },
                  ),
                ),
                const SizedBox(width: 8),
                if (!widget.receptionMode)
  Expanded(
    child: ElevatedButton.icon(
      icon: const Icon(Icons.delete),
      label: const Text('Delete'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      onPressed: () => _confirmDelete(id),
    ),
  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadPrescriptions();
  }

  @override
void dispose() {
  _refreshTimer?.cancel();
  _scrollController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prescription History (${_prescriptions.length})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No prescriptions found')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
  controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount:
    _prescriptions.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _prescriptions.length) {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Center(
      child: CircularProgressIndicator(),
    ),
  );
}

final item = _prescriptions[index];

return _buildCard(item);
                    },
                  ),
                ),
    );
  }
}