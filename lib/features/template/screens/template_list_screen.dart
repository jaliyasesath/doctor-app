import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/app_error_ui.dart';
import '../data/template_service.dart';
import '../models/template_model.dart';
import '../../prescription/data/prescription_store.dart';
import '../../prescription/models/prescription_item.dart';
import 'template_edit_screen.dart';
import 'desktop_template_list_view.dart';

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
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await TemplateService.getTemplates();

      if (!mounted) return;

      setState(() {
        _templates = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppErrorUi.show(context, error, onRetry: _loadTemplates);
    }
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
          medicineId: int.tryParse(e['medicine_id']?.toString() ?? ''),
          medicineName: e['name']?.toString() ?? '',
          dosage: e['dosage']?.toString() ?? '',
          frequency: e['frequency']?.toString() ?? '',
          duration: e['duration']?.toString() ?? '',
          instructions: e['instructions']?.toString() ?? '',
          prescriptionOnly: e['prescription_only'] == true ||
              e['prescription_only'] == 1 ||
              e['prescription_only']?.toString() == '1',
          unitPrice:
              double.tryParse(e['unit_price']?.toString() ?? '') ?? 0,
          quantity: double.tryParse(e['quantity']?.toString() ?? '') ?? 1,
          lineTotal: double.tryParse(e['line_total']?.toString() ?? '') ??
              ((double.tryParse(e['unit_price']?.toString() ?? '') ?? 0) *
                  (double.tryParse(e['quantity']?.toString() ?? '') ?? 1)),
        );
      }).toList(),
    );

    Navigator.pop(context, true);
  }

  Future<void> _deleteTemplate(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text(
          'Delete this prescription template? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await TemplateService.deleteTemplate(id);
      await _loadTemplates();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      AppErrorUi.show(context, error, onRetry: () => _deleteTemplate(id));
    }
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
    if (Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000) {
      return DesktopTemplateListView(
        templates: _templates,
        loading: _isLoading,
        onRefresh: _loadTemplates,
        onUse: _applyTemplate,
        onEdit: _openEditTemplate,
        onDelete: (template) {
          final id = template.id;
          if (id != null) _deleteTemplate(id);
        },
        onBack: () => Navigator.pop(context),
      );
    }

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
