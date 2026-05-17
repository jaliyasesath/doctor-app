import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import 'patient_profile_screen.dart';

class PatientHistoryScreen extends StatefulWidget {
  const PatientHistoryScreen({super.key});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];

  bool _isLoading = false;

  int? _doctorId;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initDoctor();
  }

  Future<void> _initDoctor() async {
    final doctorId = await DoctorSession.getDoctorId();

    if (!mounted) return;

    if (doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor session not found. Login again.')),
      );
      return;
    }

    _doctorId = doctorId;

    await DatabaseHelper.instance.assignOldLocalDataToDoctor(doctorId);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (_doctorId == null) {
      final doctorId = await DoctorSession.getDoctorId();
      if (doctorId == null) return;
      _doctorId = doctorId;
    }

    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await DatabaseHelper.instance.searchPatientsByDoctor(
        _doctorId!,
        query,
      );

      if (!mounted) return;

      setState(() {
        _results = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  void _openPatientProfile(Map<String, dynamic> patient) {
    final patientId = patient['id'] as int;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProfileScreen(
          patientId: patientId,
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_searchController.text.trim().isNotEmpty) {
      await _search();
    }
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

  @override
void dispose() {
  _searchController.dispose();
  _searchDebounce?.cancel();
  super.dispose();
}

  Widget _buildPatientTile(Map<String, dynamic> item) {
    final phone = _getPhone(item);
    final subtitlePhone = phone.trim().isEmpty ? 'No phone' : phone;

    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(_getName(item)),
      subtitle: Text(
        'Age: ${_getAge(item)} | ${_getGender(item)} | $subtitlePhone',
      ),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => _openPatientProfile(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient History'),
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
              onChanged: (_) {
  _searchDebounce?.cancel();

  _searchDebounce = Timer(
    const Duration(milliseconds: 350),
    () {
      _search();
    },
  );
},
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _results.isEmpty
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No results')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return _buildPatientTile(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}