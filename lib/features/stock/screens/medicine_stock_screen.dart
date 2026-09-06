import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/app_error_ui.dart';
import '../../auth/data/doctor_session.dart';
import '../../notifications/services/local_notification_service.dart';
import '../../sync/services/auto_sync_service.dart';
import '../data/medicine_stock_api_service.dart';
import '../domain/stock_validation.dart';

class MedicineStockScreen extends StatefulWidget {
  const MedicineStockScreen({super.key});

  @override
  State<MedicineStockScreen> createState() => _MedicineStockScreenState();
}

class _MedicineStockScreenState extends State<MedicineStockScreen>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 50;
  static const _green = Color(0xFF0F766E);
  static const _deepGreen = Color(0xFF064E3B);
  static const _freshGreen = Color(0xFF22A06B);
  static const _appBarAccent = Color(0xFFFFD166);
  static const _appBarAccentMuted = Color(0xFFFFE7A3);
  static const _surface = Color(0xFFF1F8F6);

  final _api = MedicineStockApiService();
  final _search = TextEditingController();
  late final TabController _tabs;
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _movements = [];
  Map<String, dynamic> _valuation = {};
  int _summaryPage = 1;
  int _batchPage = 1;
  int _movementPage = 1;
  int _summaryTotal = 0;
  int _lowStockCount = 0;
  int _expiryAlertCount = 0;
  num _totalAvailableQuantity = 0;
  bool _summaryHasMore = false;
  bool _batchesHasMore = false;
  bool _movementsHasMore = false;
  bool _loadingMoreSummary = false;
  bool _loadingMoreBatches = false;
  bool _loadingMoreMovements = false;
  bool _batchesLoaded = false;
  bool _movementsLoaded = false;
  bool _mutationInProgress = false;
  bool _canManageStock = false;
  int _lowStockThreshold = 10;
  int _expiringWithinDays = 90;
  bool _showingOfflineCache = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    _loadRole();
    _load();
  }

  Future<void> _loadRole() async {
    final role = await DoctorSession.getRole();
    if (!mounted) return;
    setState(() => _canManageStock = role.toLowerCase() == 'doctor');
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1 && !_batchesLoaded) {
      _loadBatches(reset: true);
    } else if (_tabs.index == 2 && !_movementsLoaded) {
      _loadMovements(reset: true);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    final raw = response is Map ? response['data'] : null;
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _lowStockThreshold = prefs.getInt('stock_low_threshold') ?? 10;
      _expiringWithinDays = prefs.getInt('stock_expiry_days') ?? 90;
      // Medicines are created offline-first. Complete any pending medicine
      // upload before requesting the server-owned stock catalogue, otherwise a
      // newly added medicine can be visible locally but absent from Receive Stock.
      await AutoSyncService.syncPendingChanges();

      final summaryResponse = await _api.summary(
        search: _search.text.trim(),
        page: 1,
        pageSize: _pageSize,
        lowStockThreshold: _lowStockThreshold,
        expiringWithinDays: _expiringWithinDays,
      );

      // Valuation is supplementary. Its failure must not hide a valid medicine
      // catalogue or block stock receiving.
      Map<String, dynamic> valuation = {};
      try {
        valuation = await _api.valuation();
      } catch (_) {
        final cached = prefs.getString('stock_valuation_cache');
        if (cached != null) {
          try {
            final decoded = jsonDecode(cached);
            if (decoded is Map) {
              valuation = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            valuation = {};
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _summary = _rows(summaryResponse);
        _summaryPage = 1;
        _summaryHasMore = summaryResponse['hasMore'] == true;
        _summaryTotal = _id(summaryResponse['total']);
        _lowStockCount = _id(summaryResponse['lowStockCount']);
        _expiryAlertCount = _id(summaryResponse['expiryAlertCount']);
        _totalAvailableQuantity =
            _number(summaryResponse['totalAvailableQuantity']);
        _valuation = valuation;
        _showingOfflineCache = false;
      });
      await prefs.setString('stock_summary_cache', jsonEncode(_summary));
      await prefs.setString('stock_valuation_cache', jsonEncode(_valuation));
      await LocalNotificationService.showDailyStockAlert(
        lowStockCount: _lowStockCount,
        expiryAlertCount: _expiryAlertCount,
      );
    } catch (error) {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      try {
        final summary = jsonDecode(prefs.getString('stock_summary_cache') ?? '[]');
        final batches = jsonDecode(prefs.getString('stock_batches_cache') ?? '[]');
        final movements = jsonDecode(prefs.getString('stock_movements_cache') ?? '[]');
        final valuation = jsonDecode(prefs.getString('stock_valuation_cache') ?? '{}');
        if (summary is List && summary.isNotEmpty) {
          setState(() {
            _summary = summary.map((e) => Map<String, dynamic>.from(e)).toList();
            _batches = (batches as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            _movements = (movements as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            _valuation = Map<String, dynamic>.from(valuation as Map);
            _summaryTotal = _summary.length;
            _lowStockCount =
                _summary.where((x) => x['isLowStock'] == true).length;
            _expiryAlertCount = _summary
                .where((x) =>
                    x['isExpired'] == true || x['isExpiringSoon'] == true)
                .length;
            _totalAvailableQuantity = _summary.fold<num>(
              0,
              (total, item) => total + _number(item['availableQuantity']),
            );
            _summaryHasMore = false;
            _batchesHasMore = false;
            _movementsHasMore = false;
            _batchesLoaded = _batches.isNotEmpty;
            _movementsLoaded = _movements.isNotEmpty;
            _showingOfflineCache = true;
            _error = null;
          });
        } else {
          setState(() => _error = error);
        }
      } catch (_) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreSummary() async {
    if (_loadingMoreSummary || !_summaryHasMore || _showingOfflineCache) return;
    setState(() => _loadingMoreSummary = true);
    try {
      final nextPage = _summaryPage + 1;
      final response = await _api.summary(
        search: _search.text.trim(),
        page: nextPage,
        pageSize: _pageSize,
        lowStockThreshold: _lowStockThreshold,
        expiringWithinDays: _expiringWithinDays,
      );
      if (!mounted) return;
      setState(() {
        _summary.addAll(_rows(response));
        _summaryPage = nextPage;
        _summaryHasMore = response['hasMore'] == true;
      });
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error, onRetry: _loadMoreSummary);
    } finally {
      if (mounted) setState(() => _loadingMoreSummary = false);
    }
  }

  Future<void> _loadBatches({bool reset = false}) async {
    if (_loadingMoreBatches || (!reset && !_batchesHasMore)) return;
    setState(() => _loadingMoreBatches = true);
    try {
      final page = reset ? 1 : _batchPage + 1;
      final response = await _api.batches(page: page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        if (reset) _batches.clear();
        _batches.addAll(_rows(response));
        _batchPage = page;
        _batchesHasMore = response['hasMore'] == true;
        _batchesLoaded = true;
        _showingOfflineCache = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stock_batches_cache', jsonEncode(_batches));
    } catch (error) {
      if (mounted) {
        AppErrorUi.show(
          context,
          error,
          onRetry: () => _loadBatches(reset: reset),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreBatches = false);
    }
  }

  Future<void> _loadMovements({bool reset = false}) async {
    if (_loadingMoreMovements || (!reset && !_movementsHasMore)) return;
    setState(() => _loadingMoreMovements = true);
    try {
      final page = reset ? 1 : _movementPage + 1;
      final response = await _api.movements(page: page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        if (reset) _movements.clear();
        _movements.addAll(_rows(response));
        _movementPage = page;
        _movementsHasMore = response['hasMore'] == true;
        _movementsLoaded = true;
        _showingOfflineCache = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stock_movements_cache', jsonEncode(_movements));
    } catch (error) {
      if (mounted) {
        AppErrorUi.show(
          context,
          error,
          onRetry: () => _loadMovements(reset: reset),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreMovements = false);
    }
  }

  num _number(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
  int _id(dynamic value) => _number(value).toInt();
  String _text(dynamic value) => value?.toString() ?? '';

  String _defaultPriceText(dynamic value) {
    if (value == null) return '0';
    return _number(value).toStringAsFixed(2);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_mutationInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A stock update is already being processed.'),
        ),
      );
      return;
    }
    if (_showingOfflineCache) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock changes require an online connection.'),
        ),
      );
      return;
    }
    setState(() => _mutationInProgress = true);
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully.')),
      );
      await _load();
      if (_tabs.index == 1) await _loadBatches(reset: true);
      if (_tabs.index == 2) await _loadMovements(reset: true);
    } catch (error) {
      if (!mounted) return;
      AppErrorUi.show(
        context,
        error,
        onRetry: () => _run(operation),
      );
    } finally {
      if (mounted) setState(() => _mutationInProgress = false);
    }
  }

  String _key(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _receive() async {
    List<Map<String, dynamic>> medicines;
    try {
      medicines = _rows(await _api.allSummary(
        lowStockThreshold: _lowStockThreshold,
        expiringWithinDays: _expiringWithinDays,
      ));
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error, onRetry: _receive);
      return;
    }
    if (!mounted) return;
    if (medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No cloud-synced medicines are available. Sync the medicine and try again.',
          ),
        ),
      );
      return;
    }
    var medicine = medicines.first;
    final batch = TextEditingController();
    final quantity = TextEditingController();
    final cost = TextEditingController(
      text: _defaultPriceText(medicine['defaultCostPrice']),
    );
    final selling = TextEditingController(
      text: _defaultPriceText(medicine['defaultSellingPrice']),
    );
    final notes = TextEditingController();
    DateTime? expiry;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Receive Stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: medicine,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Medicine'),
                  items: medicines
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_text(item['medicineName'])),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    medicine = value;
                    cost.text = _defaultPriceText(
                      medicine['defaultCostPrice'],
                    );
                    selling.text = _defaultPriceText(
                      medicine['defaultSellingPrice'],
                    );
                  },
                ),
                TextField(
                  controller: batch,
                  decoration: const InputDecoration(labelText: 'Batch number'),
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost price'),
                ),
                TextField(
                  controller: selling,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Selling price'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expiry date'),
                  subtitle: Text(
                    expiry == null
                        ? 'Not selected'
                        : expiry!.toIso8601String().split('T').first,
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => expiry = picked);
                    }
                  },
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Receive'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final qty = num.tryParse(quantity.text);
    final validation = StockValidation.receive(
      batchNumber: batch.text,
      quantity: qty ?? 0,
      costPrice: num.tryParse(cost.text) ?? -1,
      sellingPrice: num.tryParse(selling.text) ?? -1,
      expiryDate: expiry,
    );
    if (validation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation)),
        );
      }
      return;
    }
    final requestKey = _key('receive');
    await _run(() async {
      await _api.receive({
        'medicineId': _id(medicine['id']),
        'batchNumber': batch.text.trim(),
        'expiryDate': expiry?.toIso8601String().split('T').first,
        'quantity': qty,
        'costPrice': num.tryParse(cost.text) ?? 0,
        'sellingPrice': num.tryParse(selling.text) ?? 0,
        'notes': notes.text.trim(),
        'idempotencyKey': requestKey,
      });
    });
  }

  Future<void> _adjust(Map<String, dynamic> item) async {
    var direction = 'IN';
    final quantity = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust ${_text(item['medicineName'])}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: direction,
                decoration: const InputDecoration(labelText: 'Direction'),
                items: const [
                  DropdownMenuItem(value: 'IN', child: Text('Add stock')),
                  DropdownMenuItem(value: 'OUT', child: Text('Remove stock')),
                ],
                onChanged: (value) =>
                    setDialogState(() => direction = value ?? direction),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final qty = num.tryParse(quantity.text);
    final validation = StockValidation.adjustment(
      quantity: qty ?? 0,
      reason: reason.text,
    );
    if (validation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation)),
        );
      }
      return;
    }
    final requestKey = _key('adjust');
    await _run(() async {
      await _api.adjust({
        'stockBatchId': _id(item['id']),
        'direction': direction,
        'quantity': qty,
        'reason': reason.text.trim(),
        'idempotencyKey': requestKey,
      });
    });
  }

  Future<void> _dispense() async {
    if (_showingOfflineCache) {
      await _run(() async {});
      return;
    }
    Map<String, dynamic>? prescription;
    final selectedQuantities = <int, num>{};
    List<Map<String, dynamic>> prescriptions = [];
    try {
      prescriptions = _rows(await _api.allPendingPrescriptions());
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error, onRetry: _dispense);
      return;
    }
    if (!mounted) return;
    if (prescriptions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No prescriptions are waiting to be dispensed.')),
        );
      }
      return;
    }
    prescription = prescriptions.first;
    void loadItems(Map<String, dynamic> value) {
      selectedQuantities.clear();
      final items = value['items'];
      if (items is List) {
        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw as Map);
          final id = _id(item['medicineId']);
          final quantity = _number(item['quantity']);
          if (id > 0 && quantity > 0) selectedQuantities[id] = quantity;
        }
      }
    }
    loadItems(prescription);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dispense Prescription'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: prescription,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Prescription'),
                    items: prescriptions.map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        '${_text(item['prescriptionNo'])} — ${_text(item['patientName'])}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        prescription = value;
                        loadItems(value);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_number(prescription?['unmatchedItemCount']) > 0)
                    const Text(
                      'Some medicines are not linked to stock and cannot be dispensed.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ...((prescription?['items'] as List? ?? const []).map((raw) {
                    final item = Map<String, dynamic>.from(raw as Map);
                    final medicineId = _id(item['medicineId']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_text(item['medicineName'])),
                      subtitle: Text(
                        'Quantity: ${selectedQuantities[medicineId] ?? 0}',
                      ),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: _green,
                      ),
                    );
                  })),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedQuantities.isEmpty ||
                      _number(prescription?['unmatchedItemCount']) > 0
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Dispense All Stock Items'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final rxId = _id(prescription?['id']);
    if (rxId <= 0 || selectedQuantities.isEmpty) return;
    final requestKey = _key('dispense');
    await _run(() async {
      final response = await _api.dispense({
        'prescriptionId': rxId,
        'items': selectedQuantities.entries
            .map((entry) => {
                  'medicineId': entry.key,
                  'quantity': entry.value,
                })
            .toList(),
        'idempotencyKey': requestKey,
      });
      if (!mounted) return;
      final transactionId =
          response['dispenseTransactionId'] ?? response['transactionId'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispensed. Transaction ID: $transactionId')),
      );
    });
  }

  Future<void> _reverse({int? initialTransactionId}) async {
    final transactionId = TextEditingController(
      text: initialTransactionId?.toString() ?? '',
    );
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse Dispense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: transactionId,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Dispense transaction ID'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = int.tryParse(transactionId.text);
    if (id == null || id <= 0 || reason.text.trim().isEmpty) return;
    final requestKey = _key('reverse');
    await _run(() async {
      await _api.reverseDispense({
        'dispenseTransactionId': id,
        'reason': reason.text.trim(),
        'idempotencyKey': requestKey,
      });
    });
  }

  Future<void> _configureAlerts() async {
    final low = TextEditingController(text: '$_lowStockThreshold');
    final days = TextEditingController(text: '$_expiringWithinDays');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stock Alert Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: low,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Low-stock level'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Expiry warning days'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final lowValue = int.tryParse(low.text);
    final daysValue = int.tryParse(days.text);
    if (lowValue == null || lowValue < 0 ||
        daysValue == null || daysValue < 1 || daysValue > 3650) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid alert settings.')),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stock_low_threshold', lowValue);
    await prefs.setInt('stock_expiry_days', daysValue);
    await _load();
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 9),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _stockHero(int low, int expiry) {
    final totalQuantity = _totalAvailableQuantity;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_deepGreen, _green, _freshGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
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
                  'Stock Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalQuantity units  •  $low low stock  •  $expiry alerts',
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

  Widget _overview() {
    final low = _lowStockCount;
    final expiry = _expiryAlertCount;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 300) _loadMoreSummary();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_showingOfflineCache) ...[
            MaterialBanner(
              content: const Text(
                'Offline cached stock is shown. Stock changes are disabled.',
              ),
              actions: [
                TextButton(onPressed: _load, child: const Text('RETRY')),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _stockHero(low, expiry),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search medicine stock',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward),
              ),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width < 104 ? constraints.maxWidth : width,
                    child: _metric('Medicines', '$_summaryTotal',
                        Icons.medication, _green),
                  ),
                  SizedBox(
                    width: width < 104 ? constraints.maxWidth : width,
                    child: _metric('Low stock', '$low', Icons.warning_amber,
                        Colors.orange),
                  ),
                  SizedBox(
                    width: width < 104 ? constraints.maxWidth : width,
                    child: _metric('Expiry alerts', '$expiry', Icons.event_busy,
                        Colors.red),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined,
                  color: _green),
              title: const Text('Stock valuation'),
              subtitle: Text(
                'Cost: ${_number(_valuation['costValue']).toStringAsFixed(2)}  •  '
                'Retail: ${_number(_valuation['retailValue']).toStringAsFixed(2)}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          ..._summary.map((item) {
            final lowStock = item['isLowStock'] == true;
            final expired = item['isExpired'] == true;
            final expiring = item['isExpiringSoon'] == true;
            final warning = expired
                ? 'Expired'
                : expiring
                    ? 'Expiring soon'
                    : lowStock
                        ? 'Low stock'
                        : 'In stock';
            final warningColor = expired
                ? Colors.red
                : (expiring || lowStock ? Colors.orange : _green);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: warningColor.withValues(alpha: .20),
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: warningColor.withValues(alpha: .12),
                  child: Icon(Icons.medication_liquid, color: warningColor),
                ),
                title: Text(_text(item['medicineName']),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '$warning • ${_number(item['activeBatchCount'])} active batches',
                ),
                trailing: Text(
                  '${_number(item['availableQuantity'])}',
                  style: TextStyle(
                    color: warningColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }),
          if (_loadingMoreSummary)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      ),
    );
  }

  Widget _batchList() => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 300) _loadBatches();
          return false;
        },
        child: RefreshIndicator(
        onRefresh: () => _loadBatches(reset: true),
        child: !_batchesLoaded && _loadingMoreBatches
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _batches.length + (_loadingMoreBatches ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == _batches.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = _batches[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFD1E7DF)),
              ),
              child: ListTile(
                onTap: _canManageStock ? () => _adjust(item) : null,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE6F5F1),
                  child: Icon(Icons.inventory_2, color: _green),
                ),
                title: Text(_text(item['medicineName']),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'Batch ${_text(item['batchNumber'])}\n'
                  'Expiry: ${_text(item['expiryDate']).split('T').first}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_number(item['availableQuantity'])}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(
                      _canManageStock ? 'Tap to adjust' : 'View only',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      );

  Widget _movementList() => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 300) _loadMovements();
          return false;
        },
        child: RefreshIndicator(
        onRefresh: () => _loadMovements(reset: true),
        child: !_movementsLoaded && _loadingMoreMovements
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _movements.length + (_loadingMoreMovements ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == _movements.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = _movements[index];
            final quantity = _number(item['quantityChange']);
            final positive = quantity >= 0;
            final canReverse = _canManageStock &&
                _text(item['movementType']).toUpperCase() == 'DISPENSE' &&
                _text(item['referenceType']).toUpperCase() ==
                    'DISPENSE_TRANSACTION' &&
                _id(item['referenceId']) > 0;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFD1E7DF)),
              ),
              child: ListTile(
                onTap: canReverse
                    ? () => _reverse(
                          initialTransactionId: _id(item['referenceId']),
                        )
                    : null,
                leading: CircleAvatar(
                  backgroundColor:
                      (positive ? _green : Colors.red).withValues(alpha: .12),
                  child: Icon(
                    positive ? Icons.add : Icons.remove,
                    color: positive ? _green : Colors.red,
                  ),
                ),
                title: Text(_text(item['medicineName']),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${_text(item['movementType'])} • ${_text(item['notes'])}\n'
                  '${_text(item['createdAt']).replaceFirst('T', ' ')}'
                  '${canReverse ? '\nTransaction #${_id(item['referenceId'])} • Tap to reverse' : ''}',
                ),
                isThreeLine: canReverse,
                trailing: Text(
                  '${positive ? '+' : ''}$quantity',
                  style: TextStyle(
                    color: positive ? _green : Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          },
        ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: _green),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD1E7DF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _green, width: 1.6),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _deepGreen,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _appBarAccent,
          iconTheme: const IconThemeData(color: _appBarAccent),
          actionsIconTheme: const IconThemeData(color: _appBarAccent),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [_deepGreen, _green, _freshGreen]),
            ),
          ),
          title: const Text(
            'Medicine Stock',
            style: TextStyle(
              color: _appBarAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _configureAlerts,
              tooltip: 'Stock alert settings',
              icon: const Icon(Icons.tune),
            ),
            PopupMenuButton<String>(
              enabled: !_mutationInProgress,
              onSelected: (value) {
                if (value == 'dispense') _dispense();
                if (value == 'reverse') _reverse();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'dispense',
                  child: Text('Dispense prescription'),
                ),
                if (_canManageStock)
                  const PopupMenuItem(
                    value: 'reverse',
                    child: Text('Reverse dispense'),
                  ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            dividerColor: const Color(0x55FFD166),
            indicatorColor: _appBarAccent,
            indicatorWeight: 3,
            labelColor: _appBarAccent,
            unselectedLabelColor: _appBarAccentMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Batches'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: _canManageStock
            ? FloatingActionButton.extended(
                onPressed: _mutationInProgress ? null : _receive,
                backgroundColor: _green,
                foregroundColor: Colors.white,
                icon: _mutationInProgress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_box_outlined),
                label: Text(
                  _mutationInProgress ? 'Updating...' : 'Receive Stock',
                ),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Stock data could not be loaded.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [_overview(), _batchList(), _movementList()],
                  ),
      ),
    );
  }
}
