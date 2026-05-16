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
  List<Map<String, dynamic>> _allPatients = [];

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
    await _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (_doctorId == null) return;

    setState(() => _isLoading = true);

    try {
      final online = await NetworkService.isOnline();

      if (online) {
        await SyncService().syncAll();
      }

      final data = await DatabaseHelper.instance.getPatientsByDoctor(_doctorId!);

      if (!mounted) return;

      setState(() {
        _allPatients = data;
        _patients = data;
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

  Future<void> _searchPatients(String query) async {
    if (_doctorId == null) return;

    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _patients = List<Map<String, dynamic>>.from(_allPatients);
      });
      return;
    }

    try {
      final data = await DatabaseHelper.instance.searchPatientsByDoctor(
        _doctorId!,
        trimmed,
      );

      if (!mounted) return;

      setState(() {
        _patients = data;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
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
              onChanged: _searchPatients,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _patients.length,
                          itemBuilder: (context, index) {
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