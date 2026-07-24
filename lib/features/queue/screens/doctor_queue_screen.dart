import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/offline_fallback_policy.dart';
import '../../../core/widgets/app_error_ui.dart';
import '../../../data/local/database_helper.dart';
import '../../patient/data/api_patient_service.dart';
import '../../prescription/screens/prescription_list_screen.dart';

class DoctorQueueScreen extends StatefulWidget {
  const DoctorQueueScreen({super.key});

  @override
  State<DoctorQueueScreen> createState() => _DoctorQueueScreenState();
}

class _DoctorQueueScreenState extends State<DoctorQueueScreen> {
  Timer? _autoRefreshTimer;

  final ApiPatientService _api = ApiPatientService();

  bool _loading = true;
  bool _refreshing = false;
  String _selectedTab = 'waiting';
  String _error = '';

  List<dynamic> _patients = [];
  List<dynamic> _previousPendingPatients = [];

  @override
  void initState() {
    super.initState();

    _loadWaiting();

    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!mounted) return;
        _reloadCurrentTab(silent: true);
      },
    );
  }

  Future<void> _reloadCurrentTab({bool silent = false}) async {
    if (_refreshing) return;

    _refreshing = true;

    try {
      if (_selectedTab == 'completed') {
        await _loadCompleted(silent: silent);
      } else if (_selectedTab == 'skipped') {
        await _loadSkipped(silent: silent);
      } else {
        await _loadWaiting(silent: silent);
      }
    } finally {
      _refreshing = false;
    }
  }

  void _startLoading(String tab, {required bool silent}) {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _patients = [];
        if (tab == 'waiting') {
          _previousPendingPatients = [];
        }
        _selectedTab = tab;
        _error = '';
      });
    } else {
      setState(() {
        _selectedTab = tab;
        _error = '';
      });
    }
  }

  List<Map<String, dynamic>> _mapLocalPatients(
    List<Map<String, dynamic>> localPatients,
    String defaultStatus,
  ) {
    return localPatients.map((p) {
      return {
        'id': p['id'],
        'patientCode':
            p['server_id'] != null ? 'P${p['server_id']}' : 'OFF-${p['id']}',
        'queueNo': p['queue_no'] ?? p['id'],
        'queueStatus': p['queue_status'] ?? defaultStatus,
        'queueDate': p['queue_date'],
        'patientName': p['patient_name'] ?? '',
        'patientAge': p['patient_age'] ?? '',
        'patientGender': p['patient_gender'] ?? '',
        'phoneNumber': p['phone_number'] ?? '',
        'address': p['address'] ?? '',
      };
    }).toList();
  }

  Future<void> _loadWaiting({bool silent = false}) async {
    _startLoading('waiting', silent: silent);

    try {
      final data = await _api.getWaitingPatients();
      final previous = await _api.getPreviousPendingPatients();

      if (!mounted) return;

      setState(() {
        _patients = data;
        _previousPendingPatients = previous;
        _loading = false;
      });
    } catch (error) {
      if (!OfflineFallbackPolicy.isAllowed(error)) {
        if (!mounted) return;
        setState(() {
          _error = AppErrorUiModel.fromError(error).message;
          _loading = false;
        });
        return;
      }
      try {
        final db = await DatabaseHelper.instance.database;

        final localPatients = await DatabaseHelper.instance
            .getTodayQueuePatients(status: 'waiting');
        final previousPatients =
            await DatabaseHelper.instance.getPreviousPendingQueuePatients();

        if (!mounted) return;

        setState(() {
          _patients = _mapLocalPatients(localPatients, 'Waiting');
          _previousPendingPatients =
              _mapLocalPatients(previousPatients, 'Waiting');
          _loading = false;
          _error = '';
        });
      } catch (localError) {
        if (!mounted) return;

        setState(() {
          _error = AppErrorUiModel.fromError(localError).message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCompleted({bool silent = false}) async {
    _startLoading('completed', silent: silent);

    try {
      final data = await _api.getCompletedPatients();

      if (!mounted) return;

      setState(() {
        _patients = data;
        _loading = false;
      });
    } catch (error) {
      if (!OfflineFallbackPolicy.isAllowed(error)) {
        if (!mounted) return;
        setState(() {
          _error = AppErrorUiModel.fromError(error).message;
          _loading = false;
        });
        return;
      }
      try {
        final db = await DatabaseHelper.instance.database;

        final localPatients = await DatabaseHelper.instance
            .getTodayQueuePatients(status: 'Completed');

        if (!mounted) return;

        setState(() {
          _patients = _mapLocalPatients(localPatients, 'Completed');
          _loading = false;
          _error = '';
        });
      } catch (localError) {
        if (!mounted) return;

        setState(() {
          _error = AppErrorUiModel.fromError(localError).message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSkipped({bool silent = false}) async {
    _startLoading('skipped', silent: silent);

    try {
      final data = await _api.getSkippedPatients();

      if (!mounted) return;

      setState(() {
        _patients = data;
        _loading = false;
      });
    } catch (error) {
      if (!OfflineFallbackPolicy.isAllowed(error)) {
        if (!mounted) return;
        setState(() {
          _error = AppErrorUiModel.fromError(error).message;
          _loading = false;
        });
        return;
      }
      try {
        final db = await DatabaseHelper.instance.database;

        final localPatients = await DatabaseHelper.instance
            .getTodayQueuePatients(status: 'Skipped');

        if (!mounted) return;

        setState(() {
          _patients = _mapLocalPatients(localPatients, 'Skipped');
          _loading = false;
          _error = '';
        });
      } catch (localError) {
        if (!mounted) return;

        setState(() {
          _error = AppErrorUiModel.fromError(localError).message;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _skipPatient(int id) async {
    try {
      await _api.skipPatient(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient skipped')),
      );

      await _loadWaiting(silent: false);
    } catch (e) {
      if (!mounted) return;

      AppErrorUi.show(
        context,
        e,
        onRetry: () => _skipPatient(id),
      );
    }
  }

  Future<void> _movePatientToToday(int id) async {
    try {
      await _api.movePatientToToday(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient moved to today queue'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadWaiting(silent: false);
    } catch (e) {
      if (!mounted) return;
      AppErrorUi.show(
        context,
        e,
        onRetry: () => _movePatientToToday(id),
      );
    }
  }

  Future<void> _completePatient(int id) async {
    try {
      await _api.completePatient(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient completed')),
      );

      await _reloadCurrentTab(silent: false);
    } catch (e) {
      if (!mounted) return;
      AppErrorUi.show(
        context,
        e,
        onRetry: () => _completePatient(id),
      );
    }
  }

  Widget _patientCard(
    Map<String, dynamic> p, {
    bool isPreviousPending = false,
  }) {
    final id = p['id'] as int;
    final code = p['patientCode']?.toString() ?? '-';
    final queueNo = p['queueNo']?.toString() ?? '-';
    final name = p['patientName']?.toString() ?? '';
    final age = p['patientAge']?.toString() ?? '';
    final gender = p['patientGender']?.toString() ?? '';
    final phone = p['phoneNumber']?.toString() ?? '';
    final status = p['queueStatus']?.toString() ?? '';
    final queueDate = p['queueDate']?.toString() ?? '';

    final isServing = status == 'Serving';
    final isCompleted = status == 'Completed';
    final isSkipped = status == 'Skipped';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isServing
          ? Colors.green.shade50
          : isCompleted
              ? Colors.blue.shade50
              : isSkipped
                  ? Colors.orange.shade50
                  : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(queueNo)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Unnamed Patient' : name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  backgroundColor: isServing
                      ? Colors.green
                      : isCompleted
                          ? Colors.blue
                          : isSkipped
                              ? Colors.orange
                              : Colors.blueGrey,
                  label: Text(
                    status,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Patient ID: $code'),
            Text('Age/Gender: $age / $gender'),
            if (phone.isNotEmpty) Text('Phone: $phone'),
            if (queueDate.isNotEmpty)
              Text(
                'Queue Date: ${queueDate.split('T').first}',
                style: TextStyle(
                  color: isPreviousPending ? Colors.deepOrange : Colors.black54,
                  fontWeight:
                      isPreviousPending ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            const SizedBox(height: 12),
            if (isPreviousPending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _movePatientToToday(id),
                    icon: const Icon(Icons.today),
                    label: const Text('Move to Today'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _completePatient(id),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Complete'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _skipPatient(id),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!isCompleted && !isSkipped) {
                          try {
                            await _api.setServingPatient(id);
                          } catch (_) {}
                        }

                        if (!mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrescriptionListScreen(
                              patientName: name,
                              patientAge: age,
                              patientGender: gender,
                              patientPhone: phone,
                              patientAddress: p['address']?.toString() ?? '',
                              existingPatientId: id,
                            ),
                          ),
                        );

                        await _reloadCurrentTab(silent: false);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(isCompleted ? 'View' : 'Open'),
                    ),
                  ),
                  if (_selectedTab == 'waiting') ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _skipPatient(id),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _completePatient(id),
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_patients.isEmpty &&
        (_selectedTab != 'waiting' || _previousPendingPatients.isEmpty)) {
      return Center(
        child: Text(
          _selectedTab == 'completed'
              ? 'No completed patients'
              : _selectedTab == 'skipped'
                  ? 'No skipped patients'
                  : 'No waiting patients',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _reloadCurrentTab(silent: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedTab == 'waiting') ...[
            _queueSectionHeader(
              icon: Icons.today,
              title: "Today's Patients",
              count: _patients.length,
              color: Colors.blue,
            ),
            const SizedBox(height: 10),
          ],
          if (_patients.isEmpty && _selectedTab == 'waiting')
            _emptySection('No patients in today queue')
          else
            ..._patients.map((item) {
              final patient = Map<String, dynamic>.from(item as Map);
              return _patientCard(patient);
            }),
          if (_selectedTab == 'waiting' &&
              _previousPendingPatients.isNotEmpty) ...[
            const SizedBox(height: 20),
            _queueSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Previous Pending',
              count: _previousPendingPatients.length,
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 5),
            const Text(
              'Patients still waiting from earlier dates',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ..._previousPendingPatients.map((item) {
              final patient = Map<String, dynamic>.from(item as Map);
              return _patientCard(
                patient,
                isPreviousPending: true,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _queueSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(0.12),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedTab == 'completed'
        ? 'Completed Patients'
        : _selectedTab == 'skipped'
            ? 'Skipped Patients'
            : 'Today Queue';

    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _reloadCurrentTab(silent: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'waiting',
                  label: Text('Waiting'),
                  icon: Icon(Icons.queue),
                ),
                ButtonSegment(
                  value: 'completed',
                  label: Text('Completed'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: 'skipped',
                  label: Text('Skipped'),
                  icon: Icon(Icons.skip_next),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (value) {
                final selected = value.first;

                if (selected == 'completed') {
                  _loadCompleted(silent: false);
                } else if (selected == 'skipped') {
                  _loadSkipped(silent: false);
                } else {
                  _loadWaiting(silent: false);
                }
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
