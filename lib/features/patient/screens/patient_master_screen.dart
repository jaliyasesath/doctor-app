import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../prescription/screens/patient_profile_screen.dart';
import '../../sync/services/network_service.dart';
import '../../sync/services/sync_service.dart';
import 'patient_edit_screen.dart';


class PatientMasterScreen extends StatefulWidget {
  const PatientMasterScreen({super.key});

  @override
  State<PatientMasterScreen> createState() => _PatientMasterScreenState();
}

class _PatientMasterScreenState extends State<PatientMasterScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _patients = [];

bool _isLoading = true;
bool _isLoadingMore = false;
bool _hasMore = true;

int? _doctorId;
Timer? _searchDebounce;

final ScrollController _scrollController = ScrollController();

final int _limit = 30;
int _offset = 0;

  @override
void initState() {
  super.initState();

  _initAndLoad();

  _scrollController.addListener(() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMorePatients();
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
    await _loadPatients();
  }

  Future<void> _loadPatients() async {
  if (_doctorId == null) return;

  setState(() {
    _isLoading = true;
    _offset = 0;
    _hasMore = true;
  });

  try {
    final online = await NetworkService.isOnline();

    if (online) {
      await SyncService().syncAll();
    }

    final data =
        await DatabaseHelper.instance.getPatientsByDoctorPaged(
      _doctorId!,
      limit: _limit,
      offset: 0,
    );

    if (!mounted) return;

    setState(() {
      _patients = data;
      _offset = data.length;
      _hasMore = data.length == _limit;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading patients: $e')),
    );
  }
}
Future<void> _loadMorePatients() async {
  if (_doctorId == null || !_hasMore) return;

  setState(() => _isLoadingMore = true);

  try {
    final query = _searchController.text.trim();

    final data = query.isEmpty
        ? await DatabaseHelper.instance.getPatientsByDoctorPaged(
            _doctorId!,
            limit: _limit,
            offset: _offset,
          )
        : await DatabaseHelper.instance.searchPatientsByDoctorPaged(
            _doctorId!,
            query,
            limit: _limit,
            offset: _offset,
          );

    if (!mounted) return;

    setState(() {
      _patients.addAll(data);
      _offset += data.length;
      _hasMore = data.length == _limit;
      _isLoadingMore = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() => _isLoadingMore = false);
  }
}

  Future<void> _searchPatients(String query) async {
  if (_doctorId == null) return;

  final trimmed = query.trim();

  setState(() {
    _isLoading = true;
    _offset = 0;
    _hasMore = true;
  });

  try {
    final data = trimmed.isEmpty
        ? await DatabaseHelper.instance.getPatientsByDoctorPaged(
            _doctorId!,
            limit: _limit,
            offset: 0,
          )
        : await DatabaseHelper.instance.searchPatientsByDoctorPaged(
            _doctorId!,
            trimmed,
            limit: _limit,
            offset: 0,
          );

    if (!mounted) return;

    setState(() {
      _patients = data;
      _offset = data.length;
      _hasMore = data.length == _limit;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() => _isLoading = false);
  }
}

  Future<void> _deletePatient(int id) async {
    try {
      await DatabaseHelper.instance.deletePatient(id);
      await _loadPatients();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient deleted locally')),
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
          title: const Text('Delete Patient'),
          content: const Text('Are you sure you want to delete this patient?'),
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
      await _deletePatient(id);
    }
  }

  void _openEditScreen(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientEditScreen(patient: patient),
      ),
    ).then((_) => _loadPatients());
  }

  void _openProfile(Map<String, dynamic> patient) {
    final patientId = patient['id'] as int;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProfileScreen(patientId: patientId),
      ),
    );
  }

  Future<void> _refreshPatients() async {
    _searchController.clear();
    await _loadPatients();
  }

  String _getName(Map<String, dynamic> patient) {
    return (patient['patient_name'] ??
            patient['patientName'] ??
            '')
        .toString();
  }

  String _getAge(Map<String, dynamic> patient) {
    return (patient['patient_age'] ??
            patient['patientAge'] ??
            patient['age'] ??
            '')
        .toString();
  }

  String _getGender(Map<String, dynamic> patient) {
    return (patient['patient_gender'] ??
            patient['patientGender'] ??
            patient['gender'] ??
            '')
        .toString();
  }

  String _getPhone(Map<String, dynamic> patient) {
    return (patient['phone_number'] ??
            patient['phoneNumber'] ??
            '')
        .toString();
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = _getName(patient);
    final age = _getAge(patient);
    final gender = _getGender(patient);
    final phone = _getPhone(patient);
    final syncStatus = (patient['sync_status'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Age: $age'),
                  Text('Gender: $gender'),
                  Text('Phone: ${phone.isEmpty ? '-' : phone}'),
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
              onTap: () => _openProfile(patient),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Profile'),
                    onPressed: () => _openProfile(patient),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () => _openEditScreen(patient),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _confirmDelete(patient['id'] as int),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
void dispose() {
  _searchController.dispose();
  _scrollController.dispose();
  _searchDebounce?.cancel();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Master'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patient name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(
    const Duration(milliseconds: 350),
    () {
      _searchPatients(value);
    },
  );
},
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refreshPatients,
                        child: ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(child: Text('No patients found')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshPatients,
                        child: ListView.builder(
  controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount:
    _patients.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                           if (index >= _patients.length) {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Center(
      child: CircularProgressIndicator(),
    ),
  );
}

final patient = _patients[index];

return _buildPatientCard(patient);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}