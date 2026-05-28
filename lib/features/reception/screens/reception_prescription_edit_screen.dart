import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';

class ReceptionPrescriptionEditScreen extends StatefulWidget {
  final int prescriptionId;

  const ReceptionPrescriptionEditScreen({
    super.key,
    required this.prescriptionId,
  });

  @override
  State<ReceptionPrescriptionEditScreen> createState() =>
      _ReceptionPrescriptionEditScreenState();
}

class _ReceptionPrescriptionEditScreenState
    extends State<ReceptionPrescriptionEditScreen> {
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await DatabaseHelper.instance.getPrescriptionItems(
      widget.prescriptionId,
    );

    if (!mounted) return;

    setState(() {
      _items = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    await DatabaseHelper.instance.replacePrescriptionItems(
      widget.prescriptionId,
      _items,
    );

    if (!mounted) return;

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription only updated ✅'),
      ),
    );

    Navigator.pop(context, true);
  }

  void _toggle(int index, bool value) {
    setState(() {
      _items[index] = {
        ..._items[index],
        'prescription_only': value ? 1 : 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Reception Edit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No medicines found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, index) {
                    final item = _items[index];

                    final name =
                        item['medicine_name']?.toString() ?? '';

                    final dosage =
                        item['dosage']?.toString() ?? '';

                    final frequency =
                        item['frequency']?.toString() ?? '';

                    final duration =
                        item['duration']?.toString() ?? '';

                    final isPrescriptionOnly =
                        (item['prescription_only'] ?? 0) == 1;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: CheckboxListTile(
                        value: isPrescriptionOnly,
                        onChanged: (value) {
                          _toggle(index, value ?? false);
                        },
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$dosage • $frequency • $duration',
                        ),
                        secondary: const Icon(Icons.medication),
                        controlAffinity:
                            ListTileControlAffinity.trailing,
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Changes'),
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}