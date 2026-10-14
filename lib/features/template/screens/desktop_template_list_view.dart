import 'package:flutter/material.dart';

import '../../../core/widgets/desktop_module_shell.dart';
import '../data/template_service.dart';
import '../models/template_model.dart';

class DesktopTemplateListView extends StatelessWidget {
  const DesktopTemplateListView({
    super.key,
    required this.templates,
    required this.loading,
    required this.onRefresh,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
    required this.onBack,
  });

  final List<TemplateModel> templates;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<TemplateModel> onUse;
  final ValueChanged<TemplateModel> onEdit;
  final ValueChanged<TemplateModel> onDelete;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final favoriteCount = templates.where((item) => item.isFavorite).length;
    final medicineCount = templates.fold<int>(
      0,
      (total, template) =>
          total + TemplateService.decodeItems(template.itemsJson).length,
    );

    return DesktopModuleShell(
      title: 'Prescription Templates',
      subtitle: 'Select, review and maintain reusable treatment templates',
      icon: Icons.folder_copy_rounded,
      embedded: true,
      onBack: onBack,
      actions: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onBack,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: DesktopModuleShell.teal,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Prescription'),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.folder_copy_outlined,
                    label: 'Templates',
                    value: '${templates.length}',
                    color: DesktopModuleShell.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.star_rounded,
                    label: 'Favourites',
                    value: '$favoriteCount',
                    color: const Color(0xFFD99A16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.medication_outlined,
                    label: 'Medicine entries',
                    value: '$medicineCount',
                    color: const Color(0xFF4968C8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DesktopPanel(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : templates.isEmpty
                        ? const _EmptyTemplates()
                        : _table(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F8F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 4, child: Text('TEMPLATE')),
              Expanded(flex: 3, child: Text('COMPLAINT')),
              Expanded(flex: 3, child: Text('DIAGNOSIS')),
              Expanded(flex: 2, child: Text('MEDICINES')),
              SizedBox(width: 158, child: Text('ACTIONS')),
            ],
          ),
        ),
        const Divider(height: 1, color: DesktopModuleShell.line),
        Expanded(
          child: ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: DesktopModuleShell.line),
            itemBuilder: (context, index) {
              final template = templates[index];
              final itemCount =
                  TemplateService.decodeItems(template.itemsJson).length;
              return InkWell(
                onDoubleTap: () => onUse(template),
                child: Container(
                  height: 74,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: template.isFavorite
                                    ? const Color(0xFFFFF2D9)
                                    : const Color(0xFFE1F3EF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                template.isFavorite
                                    ? Icons.star_rounded
                                    : Icons.description_outlined,
                                color: template.isFavorite
                                    ? const Color(0xFFD99A16)
                                    : DesktopModuleShell.teal,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                template.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: DesktopModuleShell.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          template.complaint.isEmpty ? '-' : template.complaint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          template.diagnosis.isEmpty ? '-' : template.diagnosis,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('$itemCount item${itemCount == 1 ? '' : 's'}'),
                      ),
                      SizedBox(
                        width: 158,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Use template',
                              onPressed: () => onUse(template),
                              color: DesktopModuleShell.teal,
                              icon: const Icon(Icons.playlist_add_check_rounded),
                            ),
                            IconButton(
                              tooltip: 'Edit template',
                              onPressed: () => onEdit(template),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete template',
                              onPressed: () => onDelete(template),
                              color: const Color(0xFFD34F5F),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DesktopPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                    color: DesktopModuleShell.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  )),
              Text(label, style: const TextStyle(color: DesktopModuleShell.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_copy_outlined,
              size: 58, color: Color(0xFFA2B5B1)),
          SizedBox(height: 12),
          Text('No templates found',
              style: TextStyle(
                color: DesktopModuleShell.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}
