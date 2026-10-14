import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/desktop_module_shell.dart';
import '../data/template_service.dart';
import '../models/template_model.dart';

class TemplateEditScreen extends StatefulWidget {
  final TemplateModel template;

  const TemplateEditScreen({
    super.key,
    required this.template,
  });

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _complaintController;
  late final TextEditingController _diagnosisController;

  late List<Map<String, dynamic>> _items;
  bool _isSaving = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _complaintController =
        TextEditingController(text: widget.template.complaint);
    _diagnosisController =
        TextEditingController(text: widget.template.diagnosis);
    _items = TemplateService.decodeItems(widget.template.itemsJson);
    _isFavorite = widget.template.isFavorite;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _complaintController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter template name')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one medicine')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = TemplateModel(
        id: widget.template.id,
        name: _nameController.text.trim(),
        complaint: _complaintController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        itemsJson: TemplateService.encodeItems(_items),
        isFavorite: _isFavorite,
      );

      await TemplateService.updateTemplate(updated);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template updated')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openMedicineDialog(
      {Map<String, dynamic>? existing, int? index}) async {
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final dosageController =
        TextEditingController(text: existing?['dosage']?.toString() ?? '');
    final frequencyController =
        TextEditingController(text: existing?['frequency']?.toString() ?? '');
    final durationController =
        TextEditingController(text: existing?['duration']?.toString() ?? '');
    final instructionsController = TextEditingController(
        text: existing?['instructions']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Medicine' : 'Edit Medicine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameController, 'Medicine Name'),
                const SizedBox(height: 10),
                _field(dosageController, 'Dosage'),
                const SizedBox(height: 10),
                _field(frequencyController, 'Frequency'),
                const SizedBox(height: 10),
                _field(durationController, 'Duration'),
                const SizedBox(height: 10),
                _field(instructionsController, 'Instructions', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(existing == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final item = {
        'name': nameController.text.trim(),
        'dosage': dosageController.text.trim(),
        'frequency': frequencyController.text.trim(),
        'duration': durationController.text.trim(),
        'instructions': instructionsController.text.trim(),
        if (existing?['medicine_id'] != null)
          'medicine_id': existing!['medicine_id'],
        'prescription_only': existing?['prescription_only'] ?? false,
        'unit_price': existing?['unit_price'] ?? 0,
        'quantity': existing?['quantity'] ?? 1,
        'line_total': existing?['line_total'] ??
            ((double.tryParse(existing?['unit_price']?.toString() ?? '') ?? 0) *
                (double.tryParse(existing?['quantity']?.toString() ?? '') ??
                    1)),
      };

      if (item['name']!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine name is required')),
        );
        return;
      }

      setState(() {
        if (index != null) {
          _items[index] = item;
        } else {
          _items.add(item);
        }
      });
    }

    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> item, int index) {
    final instructions = item['instructions']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${item['dosage'] ?? ''} • ${item['frequency'] ?? ''} • ${item['duration'] ?? ''}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  instructions,
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openMedicineDialog(existing: item, index: index),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000) {
      return _buildDesktop(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Template'),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Remove Favorite' : 'Add Favorite',
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMedicineDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _complaintController,
              decoration: InputDecoration(
                labelText: 'Complaint',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisController,
              decoration: InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.list_alt_outlined),
                const SizedBox(width: 8),
                Text(
                  'Medicines (${_items.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (_isFavorite)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Favorite',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No medicines added yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                return _buildMedicineCard(entry.value, entry.key);
              }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Update Template'),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    InputDecoration decoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: DesktopModuleShell.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesktopModuleShell.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesktopModuleShell.line),
        ),
      );
    }

    return DesktopModuleShell(
      title: 'Edit Template',
      subtitle: 'Update reusable clinical details and medicine instructions',
      icon: Icons.edit_note_rounded,
      embedded: true,
      onBack: () => Navigator.pop(context),
      actions: [
        OutlinedButton.icon(
          onPressed: _isSaving
              ? null
              : () => setState(() => _isFavorite = !_isFavorite),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          icon: Icon(_isFavorite ? Icons.star_rounded : Icons.star_border_rounded),
          label: Text(_isFavorite ? 'Favourite' : 'Mark Favourite'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: DesktopModuleShell.teal,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 420,
              child: DesktopPanel(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Template information',
                        style: TextStyle(
                          color: DesktopModuleShell.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'These details are copied into the prescription when this template is used.',
                        style: TextStyle(color: DesktopModuleShell.muted),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _nameController,
                        decoration: decoration(
                          'Template Name *',
                          Icons.drive_file_rename_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _complaintController,
                        maxLines: 3,
                        decoration: decoration(
                          'Complaint',
                          Icons.chat_bubble_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _diagnosisController,
                        maxLines: 3,
                        decoration: decoration(
                          'Diagnosis',
                          Icons.medical_information_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: DesktopPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medication_outlined,
                            color: DesktopModuleShell.teal),
                        const SizedBox(width: 9),
                        Text(
                          'Medicines (${_items.length})',
                          style: const TextStyle(
                            color: DesktopModuleShell.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : () => _openMedicineDialog(),
                          style: FilledButton.styleFrom(
                            backgroundColor: DesktopModuleShell.teal,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Medicine'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.medication_liquid_outlined,
                                      size: 52, color: Color(0xFFA2B5B1)),
                                  SizedBox(height: 10),
                                  Text('No medicines added yet'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) =>
                                  _buildMedicineCard(_items[index], index),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
