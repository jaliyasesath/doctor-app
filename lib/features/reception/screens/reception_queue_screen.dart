import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../patient/data/api_patient_service.dart';
import '../../sync/services/network_service.dart';

class ReceptionQueueScreen extends StatefulWidget {
  final String initialTab;

  const ReceptionQueueScreen({
    super.key,
    this.initialTab = 'waiting',
  });

  @override
  State<ReceptionQueueScreen> createState() =>
      _ReceptionQueueScreenState();
}

class _ReceptionQueueScreenState
    extends State<ReceptionQueueScreen> {
  Timer? _autoRefreshTimer;

  final ApiPatientService _api = ApiPatientService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _loading = true;
  String _error = '';
  String _selectedTab = 'waiting';

  List<dynamic> _patients = [];

  @override
  void initState() {
    super.initState();

    _selectedTab = widget.initialTab;

    _loadData(showLoader: true);

    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        if (!mounted) return;

        _loadData();
      },
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = false}) async {
    if (showLoader && mounted) {
  setState(() {
    _loading = true;
    _error = '';
  });
}

    try {
      final online = await NetworkService.isOnline();

      List<dynamic> data = [];

      if (online) {
        if (_selectedTab == 'waiting') {
          data = await _api.getWaitingPatients();

          data = data.where((p) {
            final status =
                p['queueStatus']?.toString() ?? '';

            return status == 'Waiting' ||
                status == 'Serving';
          }).toList();
        } else if (_selectedTab == 'skipped') {
          data = await _api.getSkippedPatients();
        } else {
          data = await _api.getCompletedPatients();
        }
      } else {
        final localPatients = await _db.getPatients();

        data = localPatients.map((p) {
          return {
            'patientCode': p['server_id'] != null
                ? 'P${p['server_id']}'
                : 'OFF-${p['id']}',
            'queueNo': p['queue_no'] ?? p['id'],
            'patientName': p['patient_name'],
            'patientAge': p['patient_age'],
            'patientGender': p['patient_gender'],
            'phoneNumber': p['phone_number'],
            'queueStatus':
                p['queue_status'] ?? 'Offline',
          };
        }).where((p) {
          final status =
              p['queueStatus']?.toString() ?? '';

          if (_selectedTab == 'waiting') {
            return status == 'Waiting' ||
                status == 'Serving';
          }

          if (_selectedTab == 'completed') {
            return status == 'Completed';
          }

          if (_selectedTab == 'skipped') {
            return status == 'Skipped';
          }

          return true;
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _patients = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _patientCard(Map<String, dynamic> p) {
    final code = p['patientCode']?.toString() ?? '-';
    final queueNo = p['queueNo']?.toString() ?? '-';
    final name = p['patientName']?.toString() ?? '';
    final age = p['patientAge']?.toString() ?? '';
    final gender = p['patientGender']?.toString() ?? '';
    final phone = p['phoneNumber']?.toString() ?? '';
    final status = p['queueStatus']?.toString() ?? '';

    final isServing = status == 'Serving';
    final isCompleted = status == 'Completed';
    final isSkipped = status == 'Skipped';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: isServing
          ? Colors.green.shade50
          : isCompleted
              ? Colors.blue.shade50
              : isSkipped
                  ? Colors.orange.shade50
                  : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(queueNo),
        ),
        title: Text(
          name.isEmpty ? 'Unnamed Patient' : name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'ID: $code\n'
          'Age/Gender: $age / $gender'
          '${phone.isNotEmpty ? '\nPhone: $phone' : ''}',
        ),
        trailing: Chip(
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
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      return Center(
        child: Text(
          'No $_selectedTab patients',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        itemBuilder: (_, index) {
          final patient =
              Map<String, dynamic>.from(
            _patients[index] as Map,
          );

          return _patientCard(patient);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Reception Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                  value: 'skipped',
                  label: Text('Skipped'),
                  icon: Icon(Icons.skip_next),
                ),
                ButtonSegment(
                  value: 'completed',
                  label: Text('Done'),
                  icon: Icon(Icons.check_circle_outline),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (value) {
                setState(() {
                  _selectedTab = value.first;
                });

                _loadData();
              },
            ),
          ),
          Expanded(
            child: _body(),
          ),
        ],
      ),
    );
  }
}