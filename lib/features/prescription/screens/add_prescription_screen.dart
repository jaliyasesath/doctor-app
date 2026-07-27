import 'package:flutter/material.dart';
import '../models/prescription_item.dart';
import '../data/prescription_store.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final String medicineName;

  const AddPrescriptionScreen({
    super.key,
    required this.medicineName,
  });

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  String _selectedFrequency = 'BD';

  final List<String> _frequencyOptions = [
    'OD',
    'BD',
    'TDS',
    'QID',
    'SOS',
    'HS',
    'Morning',
    'Night',
  ];

  @override
  void dispose() {
    _dosageController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _addPrescription() {
    final dosage = _dosageController.text.trim();
    final duration = _durationController.text.trim();
    final instructions = _instructionsController.text.trim();

    if (dosage.isEmpty || duration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter dosage and duration'),
        ),
      );
      return;
    }

    final item = PrescriptionItem(
      medicineName: widget.medicineName,
      dosage: dosage,
      frequency: _selectedFrequency,
      duration: '$duration days',
      instructions: instructions,
    );

    PrescriptionStore.add(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.medicineName} added'),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildFrequencyChip(String value) {
    final bool isSelected = _selectedFrequency == value;

    return ChoiceChip(
      label: Text(value),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFrequency = value;
        });
      },
      selectedColor: Colors.blue,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Prescription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.medicineName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Dosage
            TextField(
              controller: _dosageController,
              decoration: InputDecoration(
                labelText: 'Dosage (e.g. 1 tablet / 5 ml / 1-0-1)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Frequency chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequency',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _frequencyOptions
                        .map((value) => _buildFrequencyChip(value))
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // Duration
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Duration (days)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Instructions
            TextField(
              controller: _instructionsController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Instructions (e.g. after meals)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _addPrescription,
                child: const Text('Add to Prescription'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
