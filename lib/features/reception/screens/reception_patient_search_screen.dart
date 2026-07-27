import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';

class ReceptionPatientSearchScreen extends StatefulWidget {
  const ReceptionPatientSearchScreen({super.key});

  @override
  State<ReceptionPatientSearchScreen> createState() =>
      _ReceptionPatientSearchScreenState();
}

class _ReceptionPatientSearchScreenState
    extends State<ReceptionPatientSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;

  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();

    _searchPatients();
  }

  Future<void> _searchPatients() async {
    setState(() {
      _loading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final q = _searchController.text.trim().toLowerCase();

      List<Map<String, dynamic>> result;

      if (q.isEmpty) {
        result = await db.query(
          'patients',
          orderBy: 'id DESC',
          limit: 50,
        );
      } else {
        result = await db.rawQuery(
          '''
          SELECT *
          FROM patients
          WHERE
            LOWER(patient_name) LIKE ?
            OR LOWER(phone_number) LIKE ?
            OR LOWER(server_id) LIKE ?
          ORDER BY id DESC
          ''',
          [
            '%$q%',
            '%$q%',
            '%$q%',
          ],
        );
      }

      if (!mounted) return;

      setState(() {
        _patients = result;
      });
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _addToQueue(
    Map<String, dynamic> patient,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;

      await db.update(
        'patients',
        {
          'queue_status': 'Waiting',
        },
        where: 'id = ?',
        whereArgs: [patient['id']],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${patient['patient_name']} added to queue ✅',
          ),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Widget _patientCard(
    Map<String, dynamic> patient,
  ) {
    final name = patient['patient_name']?.toString() ?? '';

    final phone = patient['phone_number']?.toString() ?? '';

    final gender = patient['patient_gender']?.toString() ?? '';

    final age = patient['patient_age']?.toString() ?? '';

    final serverId = patient['server_id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Patient ID: $serverId'),
            Text('Phone: $phone'),
            Text('Age/Gender: $age / $gender'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addToQueue(patient),
                icon: const Icon(Icons.queue),
                label: const Text('Add To Queue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Search Patients'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone or patient ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _searchPatients,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) {
                _searchPatients();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _patients.isEmpty
                    ? const Center(
                        child: Text('No patients found'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        itemCount: _patients.length,
                        itemBuilder: (_, index) {
                          return _patientCard(
                            _patients[index],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
