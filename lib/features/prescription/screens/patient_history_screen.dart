import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  int? _doctorId;
  String _genderFilter = 'All';
  String _visitFilter = 'all';
  String _sort = 'recent';
  bool _alertsOnly = false;
  Timer? _searchDebounce;
  final ScrollController _scrollController = ScrollController();
  static const int _limit = 30;
  int _offset = 0;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initDoctor();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
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
    await _search();
  }

  Future<void> _search() async {
    final generation = ++_searchGeneration;
    final query = _searchController.text.trim();

    if (_doctorId == null) {
      _doctorId = await DoctorSession.getDoctorId();
      if (_doctorId == null) return;
    }

    setState(() => _isLoading = true);

    try {
      final data =
          await DatabaseHelper.instance.searchPatientHistoryByDoctorPaged(
        _doctorId!,
        query: query,
        gender: _genderFilter,
        alertsOnly: _alertsOnly,
        visitFilter: _visitFilter,
        sort: _sort,
        limit: _limit,
        offset: 0,
      );
      final total = await DatabaseHelper.instance.countPatientHistoryByDoctor(
        _doctorId!,
        query: query,
        gender: _genderFilter,
        alertsOnly: _alertsOnly,
        visitFilter: _visitFilter,
      );
      if (!mounted ||
          generation != _searchGeneration ||
          query != _searchController.text.trim()) return;
      setState(() {
        _results = data;
        _total = total;
        _offset = data.length;
        _hasMore = data.length < total;
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

  Future<void> _loadMore() async {
    final generation = _searchGeneration;
    final query = _searchController.text.trim();
    if (_doctorId == null || !_hasMore || _isLoadingMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final data =
          await DatabaseHelper.instance.searchPatientHistoryByDoctorPaged(
        _doctorId!,
        query: query,
        gender: _genderFilter,
        alertsOnly: _alertsOnly,
        visitFilter: _visitFilter,
        sort: _sort,
        limit: _limit,
        offset: _offset,
      );
      if (!mounted ||
          generation != _searchGeneration ||
          query != _searchController.text.trim()) return;
      setState(() {
        _results.addAll(data);
        _offset += data.length;
        _hasMore = _offset < _total;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load more patients: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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

  String _friendlyDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'No visits yet';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('dd MMM yyyy').format(parsed);
  }

  bool get _hasActiveFilters =>
      _genderFilter != 'All' ||
      _visitFilter != 'all' ||
      _alertsOnly ||
      _sort != 'recent';

  void _resetFilters() {
    setState(() {
      _genderFilter = 'All';
      _visitFilter = 'all';
      _alertsOnly = false;
      _sort = 'recent';
    });
    unawaited(_search());
  }

  Future<void> _showFilters() async {
    var gender = _genderFilter;
    var visitFilter = _visitFilter;
    var sort = _sort;
    var alertsOnly = _alertsOnly;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter Patient History',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  const Text('Gender',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Wrap(
                      spacing: 8,
                      children: ['All', 'Male', 'Female', 'Other']
                          .map((x) => ChoiceChip(
                              label: Text(x),
                              selected: gender == x,
                              onSelected: (_) =>
                                  setSheetState(() => gender = x)))
                          .toList()),
                  const SizedBox(height: 14),
                  const Text('Visit history',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButtonFormField<String>(
                      value: visitFilter,
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All patients')),
                        DropdownMenuItem(
                            value: 'withVisits',
                            child: Text('With previous visits')),
                        DropdownMenuItem(
                            value: 'withoutVisits',
                            child: Text('No previous visits')),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => visitFilter = v ?? 'all')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Medical alerts only'),
                      subtitle: const Text(
                          'Allergies, chronic diseases or important alerts'),
                      value: alertsOnly,
                      onChanged: (v) => setSheetState(() => alertsOnly = v)),
                  const Text('Sort by',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  DropdownButtonFormField<String>(
                      value: sort,
                      items: const [
                        DropdownMenuItem(
                            value: 'recent',
                            child: Text('Most recently visited')),
                        DropdownMenuItem(
                            value: 'name', child: Text('Patient name A–Z')),
                        DropdownMenuItem(
                            value: 'mostVisits', child: Text('Most visits')),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => sort = v ?? 'recent')),
                  const SizedBox(height: 18),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Apply Filters'))),
                ]),
          ),
        ),
      ),
    );
    if (applied != true || !mounted) return;
    setState(() {
      _genderFilter = gender;
      _visitFilter = visitFilter;
      _sort = sort;
      _alertsOnly = alertsOnly;
    });
    await _search();
  }

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
    final chronic = _value(patient, ['chronic_diseases']);
    final importantAlert = _value(patient, ['important_alerts']);
    final visits = int.tryParse('${patient['visit_count'] ?? 0}') ?? 0;
    final lastVisit = _friendlyDate(patient['last_visit_date']);
    final patientId = patient['server_id'] ?? patient['id'];
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
                    const SizedBox(height: 7),
                    Wrap(spacing: 7, runSpacing: 5, children: [
                      _smallBadge('ID $patientId', const Color(0xFFEFF6FF),
                          const Color(0xFF1D4ED8)),
                      _smallBadge('$visits visit${visits == 1 ? '' : 's'}',
                          const Color(0xFFE6FFFB), const Color(0xFF0F766E)),
                      _smallBadge(lastVisit, const Color(0xFFF8FAFC),
                          const Color(0xFF475569)),
                    ]),
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
                    if (allergies.isEmpty && chronic.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _smallBadge('Chronic: $chronic', const Color(0xFFFFF7ED),
                          const Color(0xFFC2410C)),
                    ],
                    if (importantAlert.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _smallBadge('Alert: $importantAlert',
                          const Color(0xFFFFF1F2), const Color(0xFFBE123C)),
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

  Widget _smallBadge(String text, Color background, Color foreground) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: foreground,
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
      );

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
          hasQuery || _hasActiveFilters
              ? 'No patients found'
              : 'No patient records',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          hasQuery || _hasActiveFilters
              ? 'Try changing the search text or filters.'
              : 'Registered patients will appear here.',
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
                  'Search by name, phone, address or patient ID',
                  style: TextStyle(color: Color(0xFFCCFBF1)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Name, phone, address or ID...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _offset = 0;
                              });
                              unawaited(_search());
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: _showFilters,
                icon: Icon(_hasActiveFilters
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
                label: Text(_hasActiveFilters ? 'Filters on' : 'Filters'),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _resetFilters, child: const Text('Clear')),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Text(
                  _results.isEmpty
                      ? 'Patient directory'
                      : '$_total patient${_total == 1 ? '' : 's'} found',
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
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (index == _results.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _patientCard(_results[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
