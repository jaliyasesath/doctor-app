import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../prescription/screens/patient_history_screen.dart';
import '../../notifications/services/local_notification_service.dart';

class FollowUpScreen extends StatefulWidget {
  final int? targetPrescriptionId;

  const FollowUpScreen({
    super.key,
    this.targetPrescriptionId,
  });

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;

  List<Map<String, dynamic>> _today = [];
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _overdue = [];
  List<Map<String, dynamic>> _completed = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final doctorId = await DoctorSession.getDoctorId();

    if (doctorId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final today =
        await DatabaseHelper.instance.getTodayFollowUps(doctorId: doctorId);
    final upcoming =
        await DatabaseHelper.instance.getUpcomingFollowUps(doctorId: doctorId);
    final overdue =
        await DatabaseHelper.instance.getOverdueFollowUps(doctorId: doctorId);
    final completed =
        await DatabaseHelper.instance.getCompletedFollowUps(doctorId: doctorId);

    if (!mounted) return;

    setState(() {
      _today = today;
      _upcoming = upcoming;
      _overdue = overdue;
      _completed = completed;
      _isLoading = false;
    });
  }

  Future<void> _completeFollowUp(Map<String, dynamic> item) async {
    final id = item['id'] as int;

    await DatabaseHelper.instance.completeFollowUp(id);
    await LocalNotificationService.cancelNotification(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Follow-up marked as completed'),
      ),
    );

    await _loadData();
  }

  Future<void> _sendWhatsappReminder(Map<String, dynamic> item) async {
    final patientName = item['patient_name']?.toString() ?? 'Patient';
    final phone = item['phone_number']?.toString() ?? '';
    final note = item['follow_up_note']?.toString() ?? '';
    final date = _formatDate(item['follow_up_date']?.toString() ?? '');

    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient phone number not found'),
        ),
      );
      return;
    }

    final cleanPhone = _formatSriLankaPhone(phone);

    final message = Uri.encodeComponent(
      'Dear $patientName,\n\n'
      'This is a reminder for your follow-up visit.\n\n'
      'Date: $date\n'
      '${note.isNotEmpty ? 'Reason: $note\n' : ''}'
      '\nThank you.',
    );

    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp'),
        ),
      );
    }
  }

  String _formatSriLankaPhone(String phone) {
    var value = phone.replaceAll(' ', '').replaceAll('-', '');

    if (value.startsWith('+')) {
      value = value.substring(1);
    }

    if (value.startsWith('0')) {
      value = '94${value.substring(1)}';
    }

    return value;
  }

  String _formatDate(String value) {
    if (value.length >= 10) {
      return value.substring(0, 10);
    }
    return value;
  }

  void _openPatientHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PatientHistoryScreen(),
      ),
    );
  }

  Widget _statusSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _miniStat('Today', _today.length, Colors.orange),
          _miniStat('Upcoming', _upcoming.length, Colors.blue),
          _miniStat('Overdue', _overdue.length, Colors.red),
          _miniStat('Done', _completed.length, Colors.green),
        ],
      ),
    );
  }

  Widget _miniStat(String title, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          text,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> data, {
    required Color color,
    required bool showCompleteButton,
  }) {
    if (data.isEmpty) {
      return _emptyState('No follow-ups found');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: data.length,
        itemBuilder: (context, index) {
          return _followUpCard(
            data[index],
            color: color,
            showCompleteButton: showCompleteButton,
          );
        },
      ),
    );
  }

  Widget _followUpCard(
    Map<String, dynamic> item, {
    required Color color,
    required bool showCompleteButton,
  }) {
    final patient = item['patient_name']?.toString() ?? 'Patient';
    final note = item['follow_up_note']?.toString() ?? '';
    final date = _formatDate(item['follow_up_date']?.toString() ?? '');
    final rxNo = item['prescription_no']?.toString() ?? '';
    final isTarget =
    item['id'] == widget.targetPrescriptionId;

    return Card(
  margin: const EdgeInsets.only(bottom: 12),
  color: isTarget
      ? Colors.amber.shade50
      : null,
      shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(18),
  side: isTarget
      ? BorderSide(
          color: Colors.orange.shade700,
          width: 2,
        )
      : BorderSide.none,
),
      elevation: isTarget ? 5 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (rxNo.isNotEmpty)
                        Text(
                          'Rx: $rxNo',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(date),
                  backgroundColor: color.withOpacity(0.12),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                note,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openPatientHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendWhatsappReminder(item),
                    icon: const Icon(Icons.message),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
            if (showCompleteButton) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _completeFollowUp(item),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Follow-Ups'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Overdue'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _statusSummaryCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(
                        _today,
                        color: Colors.orange,
                        showCompleteButton: true,
                      ),
                      _buildList(
                        _upcoming,
                        color: Colors.blue,
                        showCompleteButton: true,
                      ),
                      _buildList(
                        _overdue,
                        color: Colors.red,
                        showCompleteButton: true,
                      ),
                      _buildList(
                        _completed,
                        color: Colors.green,
                        showCompleteButton: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}