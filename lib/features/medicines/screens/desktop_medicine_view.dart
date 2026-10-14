import 'package:flutter/material.dart';

import '../../../core/widgets/desktop_module_shell.dart';

class DesktopMedicineView extends StatelessWidget {
  const DesktopMedicineView({
    super.key,
    required this.medicines,
    required this.loading,
    required this.loadingMore,
    required this.isReception,
    required this.searchController,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final List<Map<String, dynamic>> medicines;
  final bool loading;
  final bool loadingMore;
  final bool isReception;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onClearSearch;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<Map<String, dynamic>> onToggleFavorite;

  String _text(Map<String, dynamic> item, List<String> keys,
      [String fallback = '-']) {
    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  bool _favorite(Map<String, dynamic> medicine) {
    final value = medicine['is_favorite'];
    return value == true || value == 1 || value?.toString() == '1';
  }

  Color _syncColor(String status) {
    switch (status.toLowerCase()) {
      case 'synced':
        return const Color(0xFF16845B);
      case 'failed':
        return const Color(0xFFD14343);
      default:
        return const Color(0xFFB7791F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteCount = medicines.where(_favorite).length;
    return DesktopModuleShell(
      title: 'Medicines',
      subtitle: 'Manage the doctor medicine library, pricing and favourites',
      icon: Icons.medication_rounded,
      embedded: true,
      onBack: () {},
      actions: [
        if (!isReception)
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: DesktopModuleShell.teal,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medicine'),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.medication_outlined,
                    label: 'Loaded medicines',
                    value: '${medicines.length}',
                    color: DesktopModuleShell.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.star_rounded,
                    label: 'Favourites',
                    value: '$favoriteCount',
                    color: const Color(0xFFD99A16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MetricCard(
                    icon: isReception
                        ? Icons.support_agent_rounded
                        : Icons.health_and_safety_outlined,
                    label: 'Access mode',
                    value: isReception ? 'Reception' : 'Doctor',
                    color: const Color(0xFF4968C8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DesktopPanel(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search medicine, generic, brand or drug group...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: onClearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF7FAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: DesktopModuleShell.line,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: DesktopModuleShell.line,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DesktopPanel(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : medicines.isEmpty
                        ? const _EmptyMedicines()
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
              Expanded(flex: 4, child: Text('MEDICINE')),
              Expanded(flex: 3, child: Text('GENERIC / GROUP')),
              Expanded(flex: 2, child: Text('STRENGTH')),
              Expanded(flex: 2, child: Text('PRICE')),
              Expanded(flex: 2, child: Text('SYNC')),
              SizedBox(width: 138, child: Text('ACTIONS')),
            ],
          ),
        ),
        const Divider(height: 1, color: DesktopModuleShell.line),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 300 && !loadingMore) {
                onLoadMore();
              }
              return false;
            },
            child: ListView.separated(
              controller: scrollController,
              itemCount: medicines.length + (loadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: DesktopModuleShell.line),
              itemBuilder: (context, index) {
                if (index >= medicines.length) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _row(medicines[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> medicine) {
    final name = _text(
      medicine,
      ['custom_medicine_name', 'medicine_name'],
      'Unnamed Medicine',
    );
    final generic = _text(medicine, ['custom_generic_name', 'generic_name']);
    final group = _text(medicine, ['custom_drug_group', 'drug_group']);
    final strength = _text(medicine, ['custom_dosage', 'strength']);
    final price = _text(medicine, ['selling_price'], '0.00');
    final status = _text(medicine, ['sync_status'], 'pending');
    final favorite = _favorite(medicine);
    final id = int.tryParse(medicine['id']?.toString() ?? '');
    final syncColor = _syncColor(status);

    return InkWell(
      onTap: () => onEdit(medicine),
      child: Container(
        height: 72,
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
                      color: const Color(0xFFE1F3EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      color: DesktopModuleShell.teal,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      name,
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
                '$generic\n$group',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 2, child: Text(strength)),
            Expanded(flex: 2, child: Text(price)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: syncColor.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: syncColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 138,
              child: Row(
                children: [
                  IconButton(
                    tooltip: favorite
                        ? 'Remove from favourites'
                        : 'Add to favourites',
                    onPressed: () => onToggleFavorite(medicine),
                    icon: Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: favorite ? const Color(0xFFD99A16) : null,
                    ),
                  ),
                  IconButton(
                    tooltip: isReception ? 'Edit price' : 'Edit medicine',
                    onPressed: () => onEdit(medicine),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (!isReception)
                    IconButton(
                      tooltip: 'Delete medicine',
                      onPressed: id == null ? null : () => onDelete(id),
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
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
              Text(
                value,
                style: const TextStyle(
                  color: DesktopModuleShell.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: const TextStyle(color: DesktopModuleShell.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyMedicines extends StatelessWidget {
  const _EmptyMedicines();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_liquid_rounded,
              size: 58, color: Color(0xFFA2B5B1)),
          SizedBox(height: 12),
          Text(
            'No medicines found',
            style: TextStyle(
              color: DesktopModuleShell.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
