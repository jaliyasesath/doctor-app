import 'package:flutter/material.dart';

import '../../../core/widgets/desktop_module_shell.dart';

class DesktopPatientMasterView extends StatelessWidget {
  const DesktopPatientMasterView({
    super.key,
    required this.patients,
    required this.isLoading,
    required this.isLoadingMore,
    required this.searchController,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.onBack,
    this.embedded = false,
  });

  final List<Map<String, dynamic>> patients;
  final bool isLoading;
  final bool isLoadingMore;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;
  final VoidCallback onBack;
  final bool embedded;

  String _value(Map<String, dynamic> p, List<String> keys,
      [String fallback = '-']) {
    for (final key in keys) {
      final value = p[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopModuleShell(
      title: 'Patients',
      subtitle: 'Search, review and manage patient records',
      icon: Icons.people_alt_rounded,
      onBack: onBack,
      embedded: embedded,
      actions: [
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: DesktopModuleShell.teal,
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Patient'),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            DesktopPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by patient name or phone number...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF7FAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: DesktopModuleShell.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: DesktopModuleShell.line),
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
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F5F1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${patients.length} patient(s)',
                      style: const TextStyle(
                        color: DesktopModuleShell.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DesktopPanel(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : patients.isEmpty
                        ? _empty()
                        : _table(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              size: 58, color: Color(0xFFA2B5B1)),
          SizedBox(height: 12),
          Text('No patients found',
              style: TextStyle(
                  color: DesktopModuleShell.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ],
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
              Expanded(flex: 4, child: Text('PATIENT')),
              Expanded(flex: 2, child: Text('AGE / GENDER')),
              Expanded(flex: 3, child: Text('PHONE')),
              Expanded(flex: 2, child: Text('SYNC')),
              SizedBox(width: 124, child: Text('ACTIONS')),
            ],
          ),
        ),
        const Divider(height: 1, color: DesktopModuleShell.line),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: patients.length + (isLoadingMore ? 1 : 0),
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: DesktopModuleShell.line),
            itemBuilder: (context, index) {
              if (index >= patients.length) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final p = patients[index];
              final name = _value(p, ['patient_name', 'patientName'],
                  'Unnamed Patient');
              final age = _value(p, ['patient_age', 'patientAge', 'age']);
              final gender =
                  _value(p, ['patient_gender', 'patientGender', 'gender']);
              final phone = _value(p, ['phone_number', 'phoneNumber']);
              final sync = _value(p, ['sync_status'], 'local');
              final id = int.tryParse(p['id']?.toString() ?? '');
              return InkWell(
                onTap: () => onOpen(p),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: const Color(0xFFDDF3EE),
                              child: Text(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: DesktopModuleShell.teal,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: DesktopModuleShell.ink,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text('$age / $gender')),
                      Expanded(flex: 3, child: Text(phone)),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: sync.toLowerCase() == 'synced'
                                  ? const Color(0xFFE5F7EE)
                                  : const Color(0xFFFFF3D8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(sync,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 124,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Open profile',
                              onPressed: () => onOpen(p),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            IconButton(
                              tooltip: 'Edit patient',
                              onPressed: () => onEdit(p),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete patient',
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
            },
          ),
        ),
      ],
    );
  }
}
