import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';

class SmartChipsSection extends StatefulWidget {
  final List<String> initialAllergies;
  final List<String> initialDiseases;
  final Function(List<String> allergies, List<String> diseases) onChanged;

  const SmartChipsSection({
    super.key,
    this.initialAllergies = const [],
    this.initialDiseases = const [],
    required this.onChanged,
  });

  @override
  State<SmartChipsSection> createState() => _SmartChipsSectionState();
}

class _SmartChipsSectionState extends State<SmartChipsSection> {
  final List<String> allergyOptions = [
    'Penicillin',
    'NSAIDs',
    'Sulfa',
    'Dust',
    'Food',
    'Seafood',
  ];

  final List<String> diseaseOptions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'CKD',
    'Heart Disease',
    'Gastritis',
  ];

  late List<String> selectedAllergies;
  late List<String> selectedDiseases;

  @override
  void initState() {
    super.initState();

    selectedAllergies = List<String>.from(widget.initialAllergies);
    selectedDiseases = List<String>.from(widget.initialDiseases);

    for (final item in selectedAllergies) {
      if (!allergyOptions.contains(item)) {
        allergyOptions.add(item);
      }
    }

    for (final item in selectedDiseases) {
      if (!diseaseOptions.contains(item)) {
        diseaseOptions.add(item);
      }
    }

    _loadSavedClinicalChips();
  }

  void _notifyParent() {
    widget.onChanged(selectedAllergies, selectedDiseases);
  }

  Future<void> _loadSavedClinicalChips() async {
    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;
    if (!mounted) return;

    final allergies = await DatabaseHelper.instance.getClinicalChips(
      doctorId: doctorId,
      category: 'allergies',
    );

    final diseases = await DatabaseHelper.instance.getClinicalChips(
      doctorId: doctorId,
      category: 'chronic diseases',
    );

    if (!mounted) return;

    setState(() {
      for (final item in allergies) {
        if (!allergyOptions.contains(item)) {
          allergyOptions.add(item);
        }
      }

      for (final item in diseases) {
        if (!diseaseOptions.contains(item)) {
          diseaseOptions.add(item);
        }
      }
    });
  }

  Future<void> _addCustomChip({
    required String title,
    required List<String> options,
    required List<String> selectedList,
  }) async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Add $title'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: title,
              hintText: 'Enter new $title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty) return;

    final cleanValue = value.trim();
    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;

    await DatabaseHelper.instance.insertClinicalChip(
      doctorId: doctorId,
      category: title.toLowerCase(),
      value: cleanValue,
    );

    if (!mounted) return;

    setState(() {
      if (!options.contains(cleanValue)) {
        options.add(cleanValue);
      }

      if (!selectedList.contains(cleanValue)) {
        selectedList.add(cleanValue);
      }
    });

    _notifyParent();
  }

  Future<void> _deleteCustomChip({
    required String title,
    required String value,
    required List<String> options,
    required List<String> selectedList,
  }) async {
    final doctorId = await DoctorSession.getDoctorId();
    if (doctorId == null) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Chip'),
          content: Text('Delete "$value" from $title?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await DatabaseHelper.instance.deleteClinicalChip(
      doctorId: doctorId,
      category: title.toLowerCase(),
      value: value,
    );

    if (!mounted) return;

    setState(() {
      options.remove(value);
      selectedList.remove(value);
    });

    _notifyParent();
  }

  Widget _chip({
    required String title,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required List<String> options,
    required List<String> selectedList,
  }) {
    final isDefault = title == 'Allergies'
        ? [
            'Penicillin',
            'NSAIDs',
            'Sulfa',
            'Dust',
            'Food',
            'Seafood',
          ].contains(label)
        : [
            'Diabetes',
            'Hypertension',
            'Asthma',
            'CKD',
            'Heart Disease',
            'Gastritis',
          ].contains(label);

    return GestureDetector(
      onLongPress: isDefault
          ? null
          : () {
              _deleteCustomChip(
                title: title,
                value: label,
                options: options,
                selectedList: selectedList,
              );
            },
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: selected ? const Icon(Icons.check, size: 16) : null,
      ),
    );
  }

  Widget _buildChips({
    required String title,
    required IconData icon,
    required List<String> options,
    required List<String> selectedList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0F766E)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _addCustomChip(
                  title: title,
                  options: options,
                  selectedList: selectedList,
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = options[index];
              final selected = selectedList.contains(item);

              return _chip(
                title: title,
                label: item,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      selectedList.remove(item);
                    } else {
                      selectedList.add(item);
                    }
                  });

                  _notifyParent();
                },
                options: options,
                selectedList: selectedList,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F766E).withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Text(
                  'Smart Medical Assist',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildChips(
              title: 'Allergies',
              icon: Icons.warning_amber_rounded,
              options: allergyOptions,
              selectedList: selectedAllergies,
            ),
            const SizedBox(height: 18),
            _buildChips(
              title: 'Chronic Diseases',
              icon: Icons.medical_services_outlined,
              options: diseaseOptions,
              selectedList: selectedDiseases,
            ),
          ],
        ),
      ),
    );
  }
}
