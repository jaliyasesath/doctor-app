import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../prescription/data/prescription_store.dart';
import '../../prescription/models/prescription_item.dart';
import '../../prescription/screens/prescription_list_screen.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MedicineDashboardScreen();
  }
}

class MedicineDashboardScreen extends StatefulWidget {
  const MedicineDashboardScreen({super.key});

  @override
  State<MedicineDashboardScreen> createState() =>
      _MedicineDashboardScreenState();
}

class _MedicineDashboardScreenState extends State<MedicineDashboardScreen> {
  static const String _favoritesKey = 'favorite_medicines';
  static const String _usageKey = 'medicine_usage';
  static const String _recentKey = 'recent_medicines';

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> medicines = [
    {
      "name": "Paracetamol",
      "type": "Tablet",
    },
    {
      "name": "Amoxicillin",
      "type": "Capsule",
    },
    {
      "name": "ORS",
      "type": "Powder",
    },
    {
      "name": "Vitamin C",
      "type": "Tablet",
    },
    {
      "name": "Ibuprofen",
      "type": "Tablet",
    },
    {
      "name": "Cetirizine",
      "type": "Tablet",
    },
    {
      "name": "Metformin",
      "type": "Tablet",
    },
    {
      "name": "Omeprazole",
      "type": "Capsule",
    },
    {
      "name": "Azithromycin",
      "type": "Tablet",
    },
    {
      "name": "Pantoprazole",
      "type": "Tablet",
    },
  ];

  final Set<String> _favoriteMedicineNames = {};
  Map<String, int> _usageCount = {};
  List<String> _recentList = [];

  String search = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedFavorites = prefs.getStringList(_favoritesKey) ?? [];
    final usageRaw = prefs.getStringList(_usageKey) ?? [];
    final recent = prefs.getStringList(_recentKey) ?? [];

    final Map<String, int> tempUsage = {};

    for (final item in usageRaw) {
      final parts = item.split('|');
      if (parts.length == 2) {
        tempUsage[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }

    if (!mounted) return;

    setState(() {
      _favoriteMedicineNames
        ..clear()
        ..addAll(savedFavorites);
      _usageCount = tempUsage;
      _recentList = recent;
      _isLoading = false;
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      _favoriteMedicineNames.toList(),
    );
  }

  Future<void> _saveUsageData() async {
    final prefs = await SharedPreferences.getInstance();

    final usageList = _usageCount.entries
        .map((e) => '${e.key}|${e.value}')
        .toList();

    await prefs.setStringList(_usageKey, usageList);
    await prefs.setStringList(_recentKey, _recentList);
  }

  bool _isFavorite(String medicineName) {
    return _favoriteMedicineNames.contains(medicineName);
  }

  Future<void> _toggleFavorite(String medicineName) async {
    final isCurrentlyFavorite = _isFavorite(medicineName);

    setState(() {
      if (isCurrentlyFavorite) {
        _favoriteMedicineNames.remove(medicineName);
      } else {
        _favoriteMedicineNames.add(medicineName);
      }
    });

    await _saveFavorites();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCurrentlyFavorite
              ? '$medicineName removed from favorites'
              : '$medicineName added to favorites',
        ),
      ),
    );
  }

  void _updateUsage(String name) {
    _usageCount[name] = (_usageCount[name] ?? 0) + 1;

    _recentList.remove(name);
    _recentList.insert(0, name);

    if (_recentList.length > 5) {
      _recentList = _recentList.take(5).toList();
    }

    _saveUsageData();
  }

  List<String> _getMostUsed() {
    final sorted = _usageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  void openQuickAddPopup(String name) {
    String selectedDosage = '1 tab';
    String selectedFrequency = 'BD';
    String selectedDuration = '3 days';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            Widget buildChips(
              List<String> options,
              String selected,
              Function(String) onSelect,
            ) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((e) {
                  final isSelected = e == selected;

                  return ChoiceChip(
                    label: Text(e),
                    selected: isSelected,
                    onSelected: (_) {
                      setStateSheet(() {
                        onSelect(e);
                      });
                    },
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  );
                }).toList(),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Dosage",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    buildChips(
                      ['1 tab', '2 tab'],
                      selectedDosage,
                      (val) => selectedDosage = val,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Frequency",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    buildChips(
                      ['OD', 'BD', 'TDS', 'QID'],
                      selectedFrequency,
                      (val) => selectedFrequency = val,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Duration",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    buildChips(
                      ['3 days', '5 days', '7 days'],
                      selectedDuration,
                      (val) => selectedDuration = val,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          PrescriptionStore.add(
                            PrescriptionItem(
                              medicineName: name,
                              dosage: selectedDosage,
                              frequency: selectedFrequency,
                              duration: selectedDuration,
                              instructions: '',
                            ),
                          );

                          _updateUsage(name);

                          Navigator.pop(context);

                          setState(() {});

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name added')),
                          );
                        },
                        child: const Text("Add Medicine"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void removeMedicine(int index) {
    final removed = PrescriptionStore.items[index].medicineName;

    setState(() {
      PrescriptionStore.items.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$removed removed')),
    );
  }

  void goToPrescription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrescriptionListScreen(),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Widget _buildPreviewPanel() {
    final items = PrescriptionStore.items;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.medication_outlined, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No medicines selected yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_outlined),
              const SizedBox(width: 8),
              Text(
                'Selected Medicines (${items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: goToPrescription,
                child: const Text('Go to Prescription'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.medicineName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.dosage} • ${item.frequency} • ${item.duration}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => removeMedicine(index),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine) {
    final medicineName = medicine["name"].toString();
    final isFavorite = _isFavorite(medicineName);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                medicine["type"].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              InkWell(
                onTap: () => _toggleFavorite(medicineName),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          Text(
            medicineName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => openQuickAddPopup(medicineName),
              child: const Text("+ Add"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = medicines
        .where(
          (m) => m["name"]
              .toString()
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();

    final favorites = filtered
        .where((m) => _isFavorite(m["name"].toString()))
        .toList();

    final mostUsed = _getMostUsed();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Dashboard"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search medicine...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        search = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  if (favorites.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "⭐ Favorites",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: favorites.map((m) {
                          final medicineName = m["name"].toString();

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 18,
                              ),
                              label: Text(medicineName),
                              onPressed: () => openQuickAddPopup(medicineName),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (mostUsed.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "🔥 Most Used",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mostUsed.map((name) {
                        return ActionChip(
                          label: Text(name),
                          onPressed: () => openQuickAddPopup(name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_recentList.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "🕒 Recent",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentList.map((name) {
                        return ActionChip(
                          label: Text(name),
                          onPressed: () => openQuickAddPopup(name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Expanded(
                    child: GridView.builder(
                      itemCount: filtered.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemBuilder: (context, index) {
                        final medicine = filtered[index];
                        return _buildMedicineCard(medicine);
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildPreviewPanel(),
    );
  }
}