import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/lab_api_service.dart';

class CreateLabOrderScreen extends StatefulWidget {
  final int patientId;
  final int? prescriptionId;
  final String patientName;
  const CreateLabOrderScreen({super.key, required this.patientId, this.prescriptionId, required this.patientName});
  @override
  State<CreateLabOrderScreen> createState() => _CreateLabOrderScreenState();
}

class _CreateLabOrderScreenState extends State<CreateLabOrderScreen> {
  static const tests = ['Full Blood Count', 'Fasting Blood Sugar', 'Lipid Profile', 'Liver Function Test',
    'Renal Function Test', 'Urine Full Report', 'Thyroid Profile'];
  final _api = LabApiService();
  final _clinical = TextEditingController();
  final _instructions = TextEditingController();
  final _custom = TextEditingController();
  List<Map<String, dynamic>> _labs = [];
  final Set<String> _selected = {};
  int? _labId;
  bool _fasting = false, _consent = false, _saving = false;
  late final String _createRequestKey =
      'lab-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  String _priority = 'Routine';
  DateTime? _sampleDate;

  @override
  void initState() { super.initState(); _loadLabs(); }
  @override
  void dispose() { _clinical.dispose(); _instructions.dispose(); _custom.dispose(); super.dispose(); }
  Future<void> _loadLabs() async { try { final labs = await _api.getLabs(); if (mounted) setState(() { _labs = labs.where((x) => x['isActive'] != false).toList(); if (_labs.isNotEmpty) _labId = _labs.first['id'] as int; }); } catch (_) {} }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _submit() async {
    if (_saving) return;
    final custom = _custom.text.trim(); if (custom.isNotEmpty) _selected.add(custom);
    if (_labId == null) { _message('Register and select a laboratory first'); return; }
    if (_selected.isEmpty) { _message('Select at least one investigation'); return; }
    if (!_consent) { _message('Confirm patient consent'); return; }
    setState(() => _saving = true);
    try {
      final result = await _api.createOrder({'patientId': widget.patientId, 'prescriptionId': widget.prescriptionId,
        'laboratoryId': _labId, 'clinicalNotes': _clinical.text.trim(), 'specialInstructions': _instructions.text.trim(),
        'priority': _priority, 'fastingRequired': _fasting, 'preferredSampleDate': _sampleDate?.toIso8601String(),
        'consentConfirmed': true, 'items': _selected.map((x) => {'testName': x, 'notes': ''}).toList()},
        idempotencyKey: _createRequestKey);
      final id = result['serverId'] as int; final orderNo = result['orderNumber']?.toString() ?? '';
      if (!mounted) return;
      final send = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Lab request saved'),
        content: Text('Order $orderNo\n\nSend the professional email to the selected laboratory now?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send Email'))])) ?? false;
      if (send) {
        final key = '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
        await _api.sendOrder(id, key);
        if (mounted) _message('Lab request email sent');
        final notify = mounted && (await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          title: const Text('WhatsApp notification'),
          content: const Text('Open WhatsApp with a short notification? Patient medical details will not be included.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open WhatsApp'))])) ?? false);
        if (notify) await _openWhatsApp(orderNo);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) _message('Lab request failed: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _openWhatsApp(String orderNo) async {
    final lab = _labs.cast<Map<String, dynamic>>().firstWhere((x) => x['id'] == _labId);
    var phone = lab['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (phone.startsWith('0')) phone = '94${phone.substring(1)}';
    if (phone.isEmpty) { if (mounted) _message('Laboratory WhatsApp number is missing'); return; }
    final text = Uri.encodeComponent('New laboratory request $orderNo was sent by email. Please check the registered laboratory inbox.');
    await launchUrl(Uri.parse('https://wa.me/$phone?text=$text'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Lab Investigations')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const Icon(Icons.person), title: Text(widget.patientName), subtitle: const Text('Patient'))),
      DropdownButtonFormField<int>(value: _labId, decoration: const InputDecoration(labelText: 'Laboratory', border: OutlineInputBorder()),
        items: _labs.map((x) => DropdownMenuItem(value: x['id'] as int, child: Text('${x['name']} ${x['branchName'] ?? ''}'))).toList(),
        onChanged: (v) => setState(() => _labId = v)), const SizedBox(height: 16),
      const Text('Investigations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      Wrap(spacing: 8, children: tests.map((test) => FilterChip(label: Text(test), selected: _selected.contains(test),
        onSelected: (v) => setState(() => v ? _selected.add(test) : _selected.remove(test)))).toList()),
      const SizedBox(height: 12), TextField(controller: _custom, decoration: const InputDecoration(labelText: 'Custom test', border: OutlineInputBorder())),
      const SizedBox(height: 16), TextField(controller: _clinical, maxLines: 3, decoration: const InputDecoration(labelText: 'Clinical notes', border: OutlineInputBorder())),
      const SizedBox(height: 12), TextField(controller: _instructions, maxLines: 3, decoration: const InputDecoration(labelText: 'Special instructions', border: OutlineInputBorder())),
      const SizedBox(height: 12), DropdownButtonFormField<String>(value: _priority, decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
        items: const [DropdownMenuItem(value: 'Routine', child: Text('Routine')), DropdownMenuItem(value: 'Urgent', child: Text('Urgent'))],
        onChanged: (v) => setState(() => _priority = v ?? 'Routine')),
      SwitchListTile(value: _fasting, onChanged: (v) => setState(() => _fasting = v), title: const Text('Fasting required')),
      ListTile(leading: const Icon(Icons.event), title: Text(_sampleDate == null ? 'Preferred sample date' : _sampleDate!.toString().substring(0, 10)),
        onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
          if (d != null) setState(() => _sampleDate = d); }),
      CheckboxListTile(value: _consent, onChanged: (v) => setState(() => _consent = v ?? false),
        title: const Text('Patient consent confirmed'), subtitle: const Text('Required before sharing medical data with the laboratory')),
      const SizedBox(height: 16), FilledButton.icon(onPressed: _saving ? null : _submit, icon: const Icon(Icons.save),
        label: Text(_saving ? 'Saving...' : 'Save Lab Request')),
    ]));
}
