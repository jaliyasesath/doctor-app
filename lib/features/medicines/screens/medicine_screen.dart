import 'dart:async';
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
  final ScrollController _scrollController = ScrollController();

  int? doctorId;

  bool loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<Map<String, dynamic>> medicines = [];

  final int _limit = 50;
  int _offset = 0;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

 Future<void> _init() async {

  doctorId =
      await DoctorSession.getActiveDoctorIdForData();

  await _loadMedicines();
}

  Future<void> _loadMedicines() async {
    if (doctorId == null) return;

    setState(() {
      loading = true;
      _offset = 0;
      _hasMore = true;
    });

    try {
      final data = await DatabaseHelper.instance.getMedicinesByDoctorPaged(
        doctorId!,
        limit: _limit,
        offset: 0,
      );

      if (!mounted) return;

      setState(() {
        medicines = List<Map<String, dynamic>>.from(data);
        _offset = data.length;
        _hasMore = data.length == _limit;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load medicines failed: $e')),
      );
    }
  }

  Future<void> _loadMoreMedicines() async {
    if (doctorId == null || !_hasMore || _isLoadingMore || loading) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = _searchController.text.trim();

      final data = query.isEmpty
          ? await DatabaseHelper.instance.getMedicinesByDoctorPaged(
              doctorId!,
              limit: _limit,
              offset: _offset,
            )
          : await DatabaseHelper.instance.searchMedicinesByDoctorPaged(
              doctorId!,
              query,
              limit: _limit,
              offset: _offset,
            );
            debugPrint('Loaded more medicines: ${data.length}, offset: $_offset');

      if (!mounted) return;

      setState(() {
        medicines = List<Map<String, dynamic>>.from(medicines)..addAll(data);
        _offset += data.length;
        _hasMore = data.length == _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
  if (!mounted) return;

  setState(() => _isLoadingMore = false);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Load more failed: $e')),
  );
}
  }

  Future<void> _searchMedicine(String value) async {
    if (doctorId == null) return;

    final query = value.trim();

    setState(() {
      loading = true;
      _offset = 0;
      _hasMore = true;
    });

    try {
      final data = query.isEmpty
          ? await DatabaseHelper.instance.getMedicinesByDoctorPaged(
              doctorId!,
              limit: _limit,
              offset: 0,
            )
          : await DatabaseHelper.instance.searchMedicinesByDoctorPaged(
              doctorId!,
              query,
              limit: _limit,
              offset: 0,
            );

      if (!mounted) return;

      setState(() {
        medicines = List<Map<String, dynamic>>.from(data);
        _offset = data.length;
        _hasMore = data.length == _limit;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
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
    final role =
    await DoctorSession.getRole();

if (role.toLowerCase() ==
    'reception') {

  if (!mounted) return;

  ScaffoldMessenger.of(context)
      .showSnackBar(

    const SnackBar(
      content: Text(
        'Reception cannot delete medicines',
      ),
    ),
  );

  return;
}
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

  Widget _buildMedicineCard(Map<String, dynamic> med) {
    final isFavorite = (med['is_favorite'] ?? 0) == 1;
    final status = med['sync_status']?.toString() ?? 'pending';
    final medicineName =
    (med['custom_medicine_name'] ?? '').toString().isNotEmpty
        ? med['custom_medicine_name'].toString()
        : med['medicine_name']?.toString() ?? '';

final genericName =
    (med['custom_generic_name'] ?? '').toString().isNotEmpty
        ? med['custom_generic_name'].toString()
        : med['generic_name']?.toString() ?? '';

final drugGroup =
    (med['custom_drug_group'] ?? '').toString().isNotEmpty
        ? med['custom_drug_group'].toString()
        : med['drug_group']?.toString() ?? '';

final strength =
    (med['custom_dosage'] ?? '').toString().isNotEmpty
        ? med['custom_dosage'].toString()
        : med['strength']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.amber : Colors.grey,
          ),
          onPressed: () => _toggleFavorite(med),
        ),
        title: Text(
  medicineName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           if (genericName.isNotEmpty)
  Text('Generic: $genericName'),
if (drugGroup.isNotEmpty)
  Text(
    'Group: $drugGroup',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (strength.isNotEmpty)
  Text('Strength: $strength'),
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
  }

  Widget _buildMedicineList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.extentAfter < 300 &&
            !_isLoadingMore &&
            !loading &&
            _hasMore) {
          _loadMoreMedicines();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: 90,
        ),
        itemCount: medicines.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= medicines.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final med = medicines[index];
          return _buildMedicineCard(med);
        },
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        _searchMedicine(value);
      },
    );
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    await _loadMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medicines (${medicines.length})'),
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
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search medicine / group / brand',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
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
                      : _buildMedicineList(),
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
  final TextEditingController _sellingPriceController =
    TextEditingController();

final TextEditingController _costPriceController =
    TextEditingController();

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

  doctorId =
      await DoctorSession.getActiveDoctorIdForData();

}

  void _fillData() {
  final med = widget.medicine;
  if (med == null) return;

  _medicineNameController.text =
      (med['custom_medicine_name'] ?? '').toString().isNotEmpty
          ? med['custom_medicine_name'].toString()
          : med['medicine_name']?.toString() ?? '';

  _genericNameController.text =
      (med['custom_generic_name'] ?? '').toString().isNotEmpty
          ? med['custom_generic_name'].toString()
          : med['generic_name']?.toString() ?? '';

  _brandNameController.text =
      (med['custom_brand_name'] ?? '').toString().isNotEmpty
          ? med['custom_brand_name'].toString()
          : med['brand_name']?.toString() ?? '';

  _drugGroupController.text =
      (med['custom_drug_group'] ?? '').toString().isNotEmpty
          ? med['custom_drug_group'].toString()
          : med['drug_group']?.toString() ?? '';

  _doseFormController.text =
      (med['custom_medicine_type'] ?? '').toString().isNotEmpty
          ? med['custom_medicine_type'].toString()
          : med['dose_form']?.toString() ?? '';

  _strengthController.text =
      (med['custom_dosage'] ?? '').toString().isNotEmpty
          ? med['custom_dosage'].toString()
          : med['strength']?.toString() ?? '';

  _sellingPriceController.text =
      med['selling_price']?.toString() ?? '';

  _costPriceController.text =
      med['cost_price']?.toString() ?? '';

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
    _sellingPriceController.dispose();
_costPriceController.dispose();
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
  TextInputType keyboardType = TextInputType.text,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
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

  // Master fields keep unchanged for existing assigned medicines
  'medicine_name': isEdit
      ? widget.medicine!['medicine_name']?.toString() ?? ''
      : _medicineNameController.text.trim(),

  'generic_name': isEdit
      ? widget.medicine!['generic_name']?.toString() ?? ''
      : _genericNameController.text.trim(),

  'brand_name': isEdit
      ? widget.medicine!['brand_name']?.toString() ?? ''
      : _brandNameController.text.trim(),

  'drug_group': isEdit
      ? widget.medicine!['drug_group']?.toString() ?? ''
      : _drugGroupController.text.trim(),

  'dose_form': isEdit
      ? widget.medicine!['dose_form']?.toString() ?? ''
      : _doseFormController.text.trim(),

  'strength': isEdit
      ? widget.medicine!['strength']?.toString() ?? ''
      : _strengthController.text.trim(),

  // Doctor-specific editable fields
  'custom_medicine_name': _medicineNameController.text.trim(),
  'custom_generic_name': _genericNameController.text.trim(),
  'custom_brand_name': _brandNameController.text.trim(),
  'custom_drug_group': _drugGroupController.text.trim(),
  'custom_medicine_type': _doseFormController.text.trim(),
  'custom_dosage': _strengthController.text.trim(),

  'selling_price':
      double.tryParse(_sellingPriceController.text.trim()) ?? 0,
  'cost_price':
      double.tryParse(_costPriceController.text.trim()) ?? 0,
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
_field(
  controller: _sellingPriceController,
  label: 'Selling Price',
  icon: Icons.sell_outlined,
  hint: 'Example: 25.00',
  keyboardType: TextInputType.number,
),

const SizedBox(height: 14),
_field(
  controller: _costPriceController,
  label: 'Cost Price',
  icon: Icons.price_change_outlined,
  hint: 'Example: 18.00',
  keyboardType: TextInputType.number,
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