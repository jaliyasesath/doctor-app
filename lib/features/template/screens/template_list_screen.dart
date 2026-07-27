import 'package:flutter/material.dart';
import '../data/template_service.dart';
import '../models/template_model.dart';
import '../../prescription/data/prescription_store.dart';
import '../../prescription/models/prescription_item.dart';
import 'template_edit_screen.dart';

class TemplateListScreen extends StatefulWidget {
  const TemplateListScreen({super.key});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  List<TemplateModel> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final data = await TemplateService.getTemplates();

    if (!mounted) return;

    setState(() {
      _templates = data;
      _isLoading = false;
    });
  }

  void _applyTemplate(TemplateModel template) {
    final items = TemplateService.decodeItems(template.itemsJson);

    PrescriptionStore.setClinicalDetails(
      complaintText: template.complaint,
      diagnosisText: template.diagnosis,
      visitNotesText: PrescriptionStore.visitNotes,
    );

    PrescriptionStore.setItems(
      items.map((e) {
        return PrescriptionItem(
          medicineName: e['name']?.toString() ?? '',
          dosage: e['dosage']?.toString() ?? '',
          frequency: e['frequency']?.toString() ?? '',
          duration: e['duration']?.toString() ?? '',
          instructions: e['instructions']?.toString() ?? '',
        );
      }).toList(),
    );

    Navigator.pop(context, true);
  }

  Future<void> _deleteTemplate(int id) async {
    await TemplateService.deleteTemplate(id);
    await _loadTemplates();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template deleted')),
    );
  }

  Future<void> _openEditTemplate(TemplateModel template) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditScreen(template: template),
      ),
    );

    if (updated == true) {
      await _loadTemplates();
    }
  }

  Widget _buildTemplateCard(TemplateModel template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                template.isFavorite ? Icons.star : Icons.folder_copy_outlined,
                color: template.isFavorite ? Colors.amber : Colors.blue,
              ),
              title: Text(
                template.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (template.complaint.isNotEmpty)
                    Text('Complaint: ${template.complaint}'),
                  if (template.diagnosis.isNotEmpty)
                    Text('Diagnosis: ${template.diagnosis}'),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _applyTemplate(template),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Use'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditTemplate(template),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteTemplate(template.id!),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
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
    final favorites = _templates.where((t) => t.isFavorite).toList();
    final others = _templates.where((t) => !t.isFavorite).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates found'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (favorites.isNotEmpty) ...[
                      const Text(
                        '⭐ Favorite Templates',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ...favorites.map(_buildTemplateCard),
                      const SizedBox(height: 6),
                    ],
                    if (others.isNotEmpty) ...[
                      const Text(
                        'All Templates',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ...others.map(_buildTemplateCard),
                    ],
                  ],
                ),
    );
  }
}
