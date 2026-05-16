import 'package:flutter/material.dart';
import '../../prescription/data/prescription_store.dart';
import '../../prescription/models/prescription_item.dart';

class MedicineDashboardScreen extends StatefulWidget {
  const MedicineDashboardScreen({super.key});

  @override
  State<MedicineDashboardScreen> createState() =>
      _MedicineDashboardScreenState();
}

class _MedicineDashboardScreenState extends State<MedicineDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> medicines = [
    {
      "name": "Paracetamol",
      "type": "Tablet",
      "favorite": true,
    },
    {
      "name": "Amoxicillin",
      "type": "Capsule",
      "favorite": true,
    },
    {
      "name": "ORS",
      "type": "Powder",
      "favorite": false,
    },
    {
      "name": "Vitamin C",
      "type": "Tablet",
      "favorite": false,
    },
    {
      "name": "Ibuprofen",
      "type": "Tablet",
      "favorite": false,
    },
    {
      "name": "Cetirizine",
      "type": "Tablet",
      "favorite": false,
    },
    {
      "name": "Metformin",
      "type": "Tablet",
      "favorite": false,
    },
    {
      "name": "Omeprazole",
      "type": "Capsule",
      "favorite": false,
    },
  ];

  String search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void addMedicine(String name) {
    PrescriptionStore.add(
      PrescriptionItem(
        medicineName: name,
        dosage: '1 tab',
        frequency: 'BD',
        duration: '3 days',
        instructions: '',
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name added to prescription')),
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

    final favorites = filtered.where((m) => m["favorite"] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Dashboard"),
      ),
      body: Padding(
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
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(m["name"].toString()),
                        onPressed: () => addMedicine(m["name"].toString()),
                      ),
                    );
                  }).toList(),
                ),
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
                  childAspectRatio: 1.18,
                ),
                itemBuilder: (context, index) {
                  final m = filtered[index];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m["type"].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (m["favorite"] == true)
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 18,
                              ),
                          ],
                        ),
                        Text(
                          m["name"].toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => addMedicine(m["name"].toString()),
                            child: const Text("+ Add"),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}