import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_error_ui.dart';
import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../sync/services/auto_sync_service.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  static const Color _ppDeepGreen = Color(0xFF064E3B);
  static const Color _ppGreen = Color(0xFF0F766E);
  static const Color _ppFreshGreen = Color(0xFF22A06B);
  static const Color _ppAppBarAccent = Color(0xFFFFD166);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? doctorId;
  bool isReception = false;

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
    final role = await DoctorSession.getRole();
    doctorId = await DoctorSession.getActiveDoctorIdForData();
    isReception = role.toLowerCase() == 'reception';

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

      AppErrorUi.show(
        context,
        e,
        onRetry: _loadMedicines,
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

      AppErrorUi.show(
        context,
        e,
        onRetry: _loadMoreMedicines,
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
      AppErrorUi.show(
        context,
        e,
        onRetry: () => _searchMedicine(query),
      );
    }
  }

  Future<void> _openMedicineForm({Map<String, dynamic>? medicine}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: MedicineFormScreen(medicine: medicine),
        ),
      ),
    );

    if (result == true) {
      await _loadMedicines();
    }
  }

  Future<bool> _deleteMedicine(
    int id, {
    bool reloadAfterDelete = true,
  }) async {
    final role = await DoctorSession.getRole();
    if (!mounted) return false;

    if (role.toLowerCase() == 'reception') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reception cannot delete medicines',
          ),
        ),
      );

      return false;
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

    if (confirm != true) return false;

    try {
      await DatabaseHelper.instance.deleteMedicine(id);
      unawaited(AutoSyncService.syncPendingChanges());

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine deleted')),
      );

      if (reloadAfterDelete) {
        await _loadMedicines();
      }

      return true;
    } catch (e) {
      if (!mounted) return false;

      AppErrorUi.show(
        context,
        e,
        onRetry: () => _deleteMedicine(id),
      );
      return false;
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> medicine) async {
    final id = medicine['id'] as int;
    final isFavorite = (medicine['is_favorite'] ?? 0) == 1;

    await DatabaseHelper.instance.toggleMedicineFavorite(id, !isFavorite);
    unawaited(AutoSyncService.syncPendingChanges());
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

    final genericName = (med['custom_generic_name'] ?? '').toString().isNotEmpty
        ? med['custom_generic_name'].toString()
        : med['generic_name']?.toString() ?? '';

    final drugGroup = (med['custom_drug_group'] ?? '').toString().isNotEmpty
        ? med['custom_drug_group'].toString()
        : med['drug_group']?.toString() ?? '';

    final strength = (med['custom_dosage'] ?? '').toString().isNotEmpty
        ? med['custom_dosage'].toString()
        : med['strength']?.toString() ?? '';

    final card = Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFD1E7DF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openMedicineForm(medicine: med),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF22A06B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.medication_rounded,
                color: Colors.white,
              ),
            ),
            title: Text(
              medicineName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF16352D),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (genericName.isNotEmpty) Text('Generic: $genericName'),
                if (drugGroup.isNotEmpty)
                  Text(
                    'Group: $drugGroup',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (strength.isNotEmpty) Text('Strength: $strength'),
                const SizedBox(height: 5),
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
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'Tap to edit',
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isFavorite
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(med),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openMedicineForm(medicine: med);
                    } else if (value == 'delete') {
                      _deleteMedicine(med['id'] as int);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(isReception ? 'Edit Price' : 'Edit'),
                    ),
                    if (!isReception)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('medicine-${med['id']}'),
      direction:
          isReception ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(height: 3),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => _deleteMedicine(
        med['id'] as int,
        reloadAfterDelete: false,
      ),
      onDismissed: (_) {
        setState(() {
          medicines.removeWhere((item) => item['id'] == med['id']);
        });
      },
      child: card,
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

  Widget _buildPageHeader() {
    final favorites =
        medicines.where((item) => (item['is_favorite'] ?? 0) == 1).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ppDeepGreen, _ppGreen, _ppFreshGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A064E3B),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medicine Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${medicines.length} medicines  â€¢  $favorites favourites',
                  style: const TextStyle(
                    color: Color(0xFFD7F5EA),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (!isReception)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openMedicineForm(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: _ppGreen, size: 20),
                      SizedBox(width: 5),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: _ppDeepGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
      backgroundColor: const Color(0xFFF3F7F6),
      appBar: AppBar(
        backgroundColor: _ppDeepGreen,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ppAppBarAccent,
        iconTheme: const IconThemeData(color: _ppAppBarAccent),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Medicines (${medicines.length})',
          style: const TextStyle(
            color: _ppAppBarAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF064E3B),
                Color(0xFF0F766E),
                Color(0xFF22A06B),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      floatingActionButton: isReception
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              onPressed: () => _openMedicineForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Medicine'),
            ),
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1E7DF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12064E3B),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search medicine / group / brand',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF0F766E),
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F7F6),
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : medicines.isEmpty
                      ? Center(
                          child: Text(
                            isReception
                                ? 'No medicines available for this doctor.'
                                : 'No medicines found.\nTap + to add medicine.',
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
  static const Color _ppDeepGreen = Color(0xFF064E3B);
  static const Color _ppGreen = Color(0xFF0F766E);
  static const Color _ppFreshGreen = Color(0xFF22A06B);
  static const Color _ppAppBarAccent = Color(0xFFFFD166);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _genericNameController = TextEditingController();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _drugGroupController = TextEditingController();
  final TextEditingController _doseFormController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();

  final TextEditingController _costPriceController = TextEditingController();

  bool isFavorite = false;
  bool saving = false;
  bool isReception = false;
  bool roleLoaded = false;
  int? doctorId;

  bool get isEdit => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _loadDoctor();
    _fillData();
  }

  Future<void> _loadDoctor() async {
    final role = await DoctorSession.getRole();
    final activeDoctorId = await DoctorSession.getActiveDoctorIdForData();

    if (!mounted) return;

    setState(() {
      doctorId = activeDoctorId;
      isReception = role.toLowerCase() == 'reception';
      roleLoaded = true;
    });
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

    _sellingPriceController.text = med['selling_price']?.toString() ?? '';

    _costPriceController.text = med['cost_price']?.toString() ?? '';

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

  String _existingMedicineValue(String key) {
    final medicine = widget.medicine;
    if (medicine == null) return '';
    return medicine[key]?.toString() ?? '';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool requiredField = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: requiredField ? (v) => _required(v, label) : null,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF0F766E)),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFE8F1EE),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1E7DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF0F766E),
            width: 1.6,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _formBanner(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ppDeepGreen, _ppGreen, _ppFreshGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26064E3B),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.add_box_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isReception
                      ? 'Update the doctor-specific medicine price.'
                      : 'Keep medicine details accurate for prescriptions and stock.',
                  style: const TextStyle(
                    color: Color(0xFFD7F5EA),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE2F4EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _ppGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF16352D),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (isReception && !isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reception cannot create medicines'),
        ),
      );
      return;
    }

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
      'custom_medicine_name': isReception
          ? _existingMedicineValue('custom_medicine_name')
          : _medicineNameController.text.trim(),
      'custom_generic_name': isReception
          ? _existingMedicineValue('custom_generic_name')
          : _genericNameController.text.trim(),
      'custom_brand_name': isReception
          ? _existingMedicineValue('custom_brand_name')
          : _brandNameController.text.trim(),
      'custom_drug_group': isReception
          ? _existingMedicineValue('custom_drug_group')
          : _drugGroupController.text.trim(),
      'custom_medicine_type': isReception
          ? _existingMedicineValue('custom_medicine_type')
          : _doseFormController.text.trim(),
      'custom_dosage': isReception
          ? _existingMedicineValue('custom_dosage')
          : _strengthController.text.trim(),

      'selling_price':
          double.tryParse(_sellingPriceController.text.trim()) ?? 0,
      'cost_price': double.tryParse(_costPriceController.text.trim()) ?? 0,
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
      unawaited(AutoSyncService.syncPendingChanges());

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

      AppErrorUi.show(
        context,
        e,
        onRetry: _saveMedicine,
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final title = isReception
        ? 'Update Medicine Price'
        : isEdit
            ? 'Edit Medicine'
            : 'Add Medicine';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F6),
      appBar: AppBar(
        backgroundColor: _ppDeepGreen,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ppAppBarAccent,
        iconTheme: const IconThemeData(color: _ppAppBarAccent),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: _ppAppBarAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF064E3B),
                Color(0xFF0F766E),
                Color(0xFF22A06B),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
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
                  _formBanner(title),
                  const SizedBox(height: 20),
                  _sectionTitle(
                    'Medicine Identity',
                    'Basic clinical and brand information',
                    Icons.biotech_outlined,
                  ),
                  _field(
                    controller: _medicineNameController,
                    label: 'Medicine Name',
                    icon: Icons.medication,
                    requiredField: true,
                    enabled: !isReception,
                    hint: 'Example: Amoxicillin',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _genericNameController,
                    label: 'Generic Name',
                    icon: Icons.science_outlined,
                    enabled: !isReception,
                    hint: 'Example: Amoxicillin',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _brandNameController,
                    label: 'Brand Name',
                    icon: Icons.local_offer_outlined,
                    enabled: !isReception,
                    hint: 'Example: Amoxil',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _drugGroupController,
                    label: 'Drug Group',
                    icon: Icons.category_outlined,
                    enabled: !isReception,
                    hint: 'Example: Penicillin / NSAID',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _doseFormController,
                    label: 'Dose Form',
                    icon: Icons.inventory_2_outlined,
                    enabled: !isReception,
                    hint: 'Tablet / Capsule / Syrup',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _strengthController,
                    label: 'Strength',
                    icon: Icons.speed_outlined,
                    enabled: !isReception,
                    hint: '500mg / 250mg / 5ml',
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle(
                    'Pricing & Preference',
                    'Doctor-specific prices and quick access',
                    Icons.payments_outlined,
                  ),
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
                    activeThumbColor: const Color(0xFF0F766E),
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFD1E7DF)),
                    ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
                                ? isReception
                                    ? 'Update Price'
                                    : 'Update Medicine'
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
