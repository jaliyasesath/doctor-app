import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../data/lab_report_api_service.dart';

class PatientLabReportsScreen extends StatefulWidget {
  final int? serverPatientId;
  final String patientName;
  const PatientLabReportsScreen({super.key, this.serverPatientId, this.patientName = ''});

  @override
  State<PatientLabReportsScreen> createState() => _PatientLabReportsScreenState();
}

class _PatientLabReportsScreenState extends State<PatientLabReportsScreen> {
  final _api = LabReportApiService();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  int? _openingId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final reports = await _api.getReports(patientId: widget.serverPatientId);
      if (mounted) setState(() => _reports = reports);
    } catch (error) {
      if (mounted) _message('Unable to load lab reports: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _open(Map<String, dynamic> report) async {
    setState(() => _openingId = report['id'] as int);
    try {
      final path = await _api.downloadReport(report);
      await OpenFilex.open(path);
    } catch (error) {
      if (mounted) _message('Unable to open report: $error');
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _review(Map<String, dynamic> report, String status) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(status == 'Reviewed' ? 'Mark report reviewed' : 'Reject report'),
      content: TextField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: status == 'Reviewed' ? 'Review notes (optional)' : 'Correction required', border: const OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))],
    )) ?? false;
    final value = notes.text.trim(); notes.dispose();
    if (!confirmed) return;
    try {
      await _api.review(id: report['id'] as int, status: status, notes: value, version: report['version'] as int);
      await _load();
      if (mounted) _message(status == 'Reviewed' ? 'Report marked reviewed' : 'Report rejected for correction');
    } catch (error) {
      if (mounted) _message('Unable to update report: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FC),
    appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Lab Reports'), if (widget.patientName.isNotEmpty) Text(widget.patientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal))])),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load,
      child: _reports.isEmpty
          ? ListView(children: const [SizedBox(height: 180), Icon(Icons.science_outlined, size: 58, color: Colors.black38), SizedBox(height: 12), Center(child: Text('No laboratory reports received yet'))])
          : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: _reports.length,
              itemBuilder: (context, index) {
                final report = _reports[index];
                final status = report['status']?.toString() ?? 'Uploaded';
                return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CircleAvatar(backgroundColor: Color(0xFFE6FFFB), child: Icon(Icons.description_outlined, color: Color(0xFF0F766E))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(report['originalFileName']?.toString() ?? 'Lab report', style: const TextStyle(fontWeight: FontWeight.w800)), Text(report['uploadedAt']?.toString().replaceFirst('T', ' ').split('.').first ?? '')])),
                      Chip(label: Text(status)),
                    ]),
                    if (widget.serverPatientId == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Patient: ${report['patientName'] ?? ''} · Lab: ${report['laboratoryName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    if ((report['laboratoryNotes']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Laboratory notes: ${report['laboratoryNotes']}')),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(onPressed: _openingId == report['id'] ? null : () => _open(report), icon: const Icon(Icons.visibility_outlined), label: Text(_openingId == report['id'] ? 'Opening...' : 'View report')),
                      OutlinedButton.icon(onPressed: status == 'Reviewed' ? null : () => _review(report, 'Reviewed'), icon: const Icon(Icons.check_circle_outline), label: const Text('Reviewed')),
                      TextButton.icon(onPressed: () => _review(report, 'Rejected'), icon: const Icon(Icons.report_problem_outlined), label: const Text('Request correction')),
                    ]),
                  ]),
                ));
              },
            ),
    ),
  );
}
