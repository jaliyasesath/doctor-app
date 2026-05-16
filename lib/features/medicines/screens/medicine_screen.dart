import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController _searchController = TextEditingController();

  int? doctorId;
  bool loading = true;
  List<Map<String, dynamic>> medicines = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    doctorId = await DoctorSession.getDoctorId();
    await _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    if (doctorId == null) return;

    final data = await DatabaseHelper.instance.getMedicinesByDoctor(doctorId!);

    if (!mounted) return;

    setState(() {
      medicines = data;
      loading = false;
    });
  }

  Future<void> _searchMedicine(String value) async {
    if (doctorId == null) return;

    if (value.trim().isEmpty) {
      await _loadMedicines();
      return;
    }

    final data = await DatabaseHelper.instance.searchMedicinesByDoctor(
      doctorId!,
      value.trim(),
    );

    if (!mounted) return;

    setState(() {
      medicines = data;
    });
  }

  Future<void> _openMedicineForm({Map<String, dynamic>? medicine}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineFormScreen(medicine: medicine),
      ),
    );

    if (result == true) {
      await _loadMedicines();
    }
  }

  Future<void> _deleteMedicine(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: const Text('Are you sure you want to delete this medicine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DatabaseHelper.instance.deleteMedicine(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicine deleted')),
    );

    await _loadMedicines();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> medicine) async {
    final id = medicine['id'] as int;
    final isFavorite = (medicine['is_favorite'] ?? 0) == 1;

    await DatabaseHelper.instance.toggleMedicineFavorite(id, !isFavorite);
    await _loadMedicines();
  }

  Color _statusColor(String status) {
    if (status == 'synced') return Colors.green;
    if (status == 'failed') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines'),
        actions: [
          IconButton(
            onPressed: () => _openMedicineForm(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMedicineForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchController,
                onChanged: _searchMedicine,
                decoration: InputDecoration(
                  hintText: 'Search medicine / group / brand',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadMedicines();
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : medicines.isEmpty
                      ? const Center(
                          child: Text(
                            'No medicines found.\nTap + to add medicine.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 14,
                            right: 14,
                            bottom: 90,
                          ),
                          itemCount: medicines.length,
                          itemBuilder: (context, index) {
                            final med = medicines[index];
                            final isFavorite =
                                (med['is_favorite'] ?? 0) == 1;
                            final status =
                                med['sync_status']?.toString() ?? 'pending';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.star
                                        : Icons.star_border,
                                    color:
                                        isFavorite ? Colors.amber : Colors.grey,
                                  ),
                                  onPressed: () => _toggleFavorite(med),
                                ),
                                title: Text(
                                  med['medicine_name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((med['generic_name'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                          'Generic: ${med['generic_name']}'),
                                    if ((med['drug_group'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        'Group: ${med['drug_group']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if ((med['strength'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text('Strength: ${med['strength']}'),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sync,
                                          size: 14,
                                          color: _statusColor(status),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openMedicineForm(medicine: med);
                                    } else if (value == 'delete') {
                                      _deleteMedicine(med['id'] as int);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
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

class MedicineFormScreen extends StatefulWidget {
  final Map<String, dynamic>? medicine;

  const MedicineFormScreen({
    super.key,
    this.medicine,
  });

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _medicineNameController =
      TextEditingController();
  final TextEditingController _genericNameController =
      TextEditingController();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _drugGroupController = TextEditingController();
  final TextEditingController _doseFormController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();

  bool isFavorite = false;
  bool saving = false;
  int? doctorId;

  bool get isEdit => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _loadDoctor();
    _fillData();
  }

  Future<void> _loadDoctor() async {
    doctorId = await DoctorSession.getDoctorId();
  }

  void _fillData() {
    final med = widget.medicine;
    if (med == null) return;

    _medicineNameController.text = med['medicine_name']?.toString() ?? '';
    _genericNameController.text = med['generic_name']?.toString() ?? '';
    _brandNameController.text = med['brand_name']?.toString() ?? '';
    _drugGroupController.text = med['drug_group']?.toString() ?? '';
    _doseFormController.text = med['dose_form']?.toString() ?? '';
    _strengthController.text = med['strength']?.toString() ?? '';
    isFavorite = (med['is_favorite'] ?? 0) == 1;
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _genericNameController.dispose();
    _brandNameController.dispose();
    _drugGroupController.dispose();
    _doseFormController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool requiredField = false,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      validator: requiredField ? (v) => _required(v, label) : null,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor session not found')),
      );
      return;
    }

    setState(() => saving = true);

    final data = {
      'doctor_id': doctorId,
      'medicine_name': _medicineNameController.text.trim(),
      'generic_name': _genericNameController.text.trim(),
      'brand_name': _brandNameController.text.trim(),
      'drug_group': _drugGroupController.text.trim(),
      'dose_form': _doseFormController.text.trim(),
      'strength': _strengthController.text.trim(),
      'is_favorite': isFavorite ? 1 : 0,
    };

    try {
      if (isEdit) {
        await DatabaseHelper.instance.updateMedicine(
          widget.medicine!['id'] as int,
          data,
        );
      } else {
        await DatabaseHelper.instance.insertMedicine(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Medicine updated' : 'Medicine saved offline',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEdit ? 'Edit Medicine' : 'Add Medicine';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(
                    controller: _medicineNameController,
                    label: 'Medicine Name',
                    icon: Icons.medication,
                    requiredField: true,
                    hint: 'Example: Amoxicillin',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _genericNameController,
                    label: 'Generic Name',
                    icon: Icons.science_outlined,
                    hint: 'Example: Amoxicillin',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _brandNameController,
                    label: 'Brand Name',
                    icon: Icons.local_offer_outlined,
                    hint: 'Example: Amoxil',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _drugGroupController,
                    label: 'Drug Group',
                    icon: Icons.category_outlined,
                    hint: 'Example: Penicillin / NSAID',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _doseFormController,
                    label: 'Dose Form',
                    icon: Icons.inventory_2_outlined,
                    hint: 'Tablet / Capsule / Syrup',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _strengthController,
                    label: 'Strength',
                    icon: Icons.speed_outlined,
                    hint: '500mg / 250mg / 5ml',
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: isFavorite,
                    onChanged: (value) {
                      setState(() => isFavorite = value);
                    },
                    title: const Text('Favorite Medicine'),
                    subtitle: const Text(
                      'Show this medicine first in prescription screen',
                    ),
                    secondary: const Icon(Icons.star_outline),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : _saveMedicine,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        saving
                            ? 'Saving...'
                            : isEdit
                                ? 'Update Medicine'
                                : 'Save Medicine',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}