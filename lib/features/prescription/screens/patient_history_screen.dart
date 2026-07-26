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

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
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
      _doctorId = await DoctorSession.getDoctorId();
      if (_doctorId == null) return;
    }

    if (query.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);

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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _search,
    );
  }

  String _value(Map<String, dynamic> p, List<String> keys) {
    for (final key in keys) {
      final value = p[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _name(Map<String, dynamic> p) =>
      _value(p, ['patient_name', 'patientName']);
  String _age(Map<String, dynamic> p) =>
      _value(p, ['patient_age', 'patientAge', 'age']);
  String _gender(Map<String, dynamic> p) =>
      _value(p, ['patient_gender', 'patientGender', 'gender']);
  String _phone(Map<String, dynamic> p) =>
      _value(p, ['phone_number', 'phoneNumber']);

  void _openPatientProfile(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientProfileScreen(patientId: patient['id'] as int),
      ),
    );
  }

  Widget _patientCard(Map<String, dynamic> patient) {
    final name = _name(patient);
    final age = _age(patient);
    final gender = _gender(patient);
    final phone = _phone(patient);
    final allergies = _value(patient, ['allergies']);
    final initial = name.isEmpty ? 'P' : name[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFFFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE9E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openPatientProfile(patient),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unnamed Patient' : name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${age.isEmpty ? 'Age -' : '$age yrs'}  •  '
                      '${gender.isEmpty ? 'Not specified' : gender}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            phone,
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ],
                    if (allergies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Allergy: $allergies',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFBE123C),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 90, 28, 20),
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xFFE6FFFB),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.manage_search_rounded,
            size: 38,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          hasQuery ? 'No patients found' : 'Search patient history',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          hasQuery
              ? 'Try a different name or phone number.'
              : 'Enter a patient name or phone number to view previous visits.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F6),
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF064E3B),
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF064E3B),
                Color(0xFF0F766E),
                Color(0xFF22A06B),
              ],
            ),
          ),
        ),
        title: const Text(
          'Patient History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find a patient',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Search by patient name or phone number',
                  style: TextStyle(color: Color(0xFFCCFBF1)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Name or phone number...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Text(
                  _results.isEmpty
                      ? 'Patient directory'
                      : '${_results.length} patient${_results.length == 1 ? '' : 's'} found',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _search,
              child: _results.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _results.length,
                      itemBuilder: (_, index) => _patientCard(_results[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
