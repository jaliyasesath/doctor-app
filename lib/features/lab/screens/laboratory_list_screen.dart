import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/lab_api_service.dart';

class LaboratoryListScreen extends StatefulWidget {
  const LaboratoryListScreen({super.key});

  @override
  State<LaboratoryListScreen> createState() => _LaboratoryListScreenState();
}

class _LaboratoryListScreenState extends State<LaboratoryListScreen> {
  final _api = LabApiService();
  List<Map<String, dynamic>> _labs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { final data = await _api.getLabs(); if (mounted) setState(() => _labs = data); }
    catch (e) { if (mounted) _message('Unable to load laboratories: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit([Map<String, dynamic>? current]) async {
    final name = TextEditingController(text: current?['name']?.toString() ?? '');
    final branch = TextEditingController(text: current?['branchName']?.toString() ?? '');
    final contact = TextEditingController(text: current?['contactPerson']?.toString() ?? '');
    final email = TextEditingController(text: current?['email']?.toString() ?? '');
    final phone = TextEditingController(text: current?['phone']?.toString() ?? '');
    final address = TextEditingController(text: current?['address']?.toString() ?? '');
    final notes = TextEditingController(text: current?['notes']?.toString() ?? '');
    double? latitude = double.tryParse(current?['latitude']?.toString() ?? '');
    double? longitude = double.tryParse(current?['longitude']?.toString() ?? '');
    bool favorite = current?['isFavorite'] == true;
    bool active = current?['isActive'] != false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        Future<void> useLocation() async {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
            if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Location permission is required')));
            return;
          }
          final position = await Geolocator.getCurrentPosition();
          setDialogState(() { latitude = position.latitude; longitude = position.longitude; });
        }

        return AlertDialog(
          title: Text(current == null ? 'Register Laboratory' : 'Edit Laboratory'),
          content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(children: [
            _field(name, 'Laboratory name *'), _field(branch, 'Branch'), _field(contact, 'Contact person'),
            _field(email, 'Official email *', keyboard: TextInputType.emailAddress),
            _field(phone, 'Phone / WhatsApp', keyboard: TextInputType.phone), _field(address, 'Address', lines: 2),
            _field(notes, 'Notes', lines: 2),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: useLocation, icon: const Icon(Icons.my_location), label: const Text('Use current GPS location'))),
            if (latitude != null && longitude != null) Align(alignment: Alignment.centerLeft,
              child: Text('${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}')),
            SwitchListTile(value: favorite, onChanged: (v) => setDialogState(() => favorite = v), title: const Text('Favorite laboratory')),
            SwitchListTile(value: active, onChanged: (v) => setDialogState(() => active = v), title: const Text('Active')),
          ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (name.text.trim().isEmpty || email.text.trim().isEmpty) return;
              Navigator.pop(context, {'id': current?['id'], 'name': name.text.trim(), 'branchName': branch.text.trim(),
                'contactPerson': contact.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(),
                'address': address.text.trim(), 'notes': notes.text.trim(), 'latitude': latitude, 'longitude': longitude,
                'isFavorite': favorite, 'isActive': active, 'expectedVersion': current?['version']});
            }, child: const Text('Save'))],
        );
      }),
    );
    for (final c in [name, branch, contact, email, phone, address, notes]) { c.dispose(); }
    if (result == null) return;
    try { await _api.saveLab(result); await _load(); if (mounted) _message('Laboratory saved'); }
    catch (e) { if (mounted) _message('Save failed: $e'); }
  }

  static Widget _field(TextEditingController controller, String label, {int lines = 1, TextInputType? keyboard}) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, maxLines: lines,
        keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));

  Future<void> _delete(Map<String, dynamic> lab) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Remove laboratory?'),
      content: Text(lab['name']?.toString() ?? ''), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))])) ?? false;
    if (!yes) return;
    try { await _api.deleteLab(lab['id'] as int, lab['version'] as int); await _load(); }
    catch (e) { if (mounted) _message('Delete failed: $e'); }
  }

  Future<void> _testEmail(Map<String, dynamic> lab) async {
    try {
      await _api.sendTestEmail(lab['id'] as int);
      if (mounted) _message('Test email sent to ${lab['email']}');
    } catch (e) {
      if (mounted) _message('Test email failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Laboratories')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_business), label: const Text('Register Lab')),
    body: RefreshIndicator(onRefresh: _load, child: _loading
      ? const Center(child: CircularProgressIndicator())
      : _labs.isEmpty ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No laboratories registered'))])
      : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _labs.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) { final lab = _labs[index]; return Card(child: ListTile(
            leading: CircleAvatar(child: Icon(lab['isFavorite'] == true ? Icons.star : Icons.science)),
            title: Text('${lab['name']}${(lab['branchName']?.toString().isNotEmpty ?? false) ? ' - ${lab['branchName']}' : ''}'),
            subtitle: Text('${lab['email']}\n${lab['phone'] ?? ''}'), isThreeLine: true,
            onTap: () => _edit(lab),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _edit(lab);
                if (value == 'test') _testEmail(lab);
                if (value == 'delete') _delete(lab);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'test', child: Text('Send test email')),
                PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ))); })),
  );
}
