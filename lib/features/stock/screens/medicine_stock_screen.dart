import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_error_ui.dart';
import '../data/medicine_stock_api_service.dart';

class MedicineStockScreen extends StatefulWidget {
  const MedicineStockScreen({super.key});

  @override
  State<MedicineStockScreen> createState() => _MedicineStockScreenState();
}

class _MedicineStockScreenState extends State<MedicineStockScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF0F766E);
  static const _deepGreen = Color(0xFF064E3B);
  static const _freshGreen = Color(0xFF22A06B);
  static const _surface = Color(0xFFF1F8F6);

  final _api = MedicineStockApiService();
  final _search = TextEditingController();
  late final TabController _tabs;
  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
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
      final results = await Future.wait([
        _api.summary(search: _search.text.trim()),
        _api.batches(),
        _api.movements(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = _rows(results[0]);
        _batches = _rows(results[1]);
        _movements = _rows(results[2]);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _number(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
  int _id(dynamic value) => _number(value).toInt();
  String _text(dynamic value) => value?.toString() ?? '';

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppErrorUi.show(context, error, onRetry: _load);
    }
  }

  String _key(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _receive() async {
    if (_summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No medicines are available.')),
      );
      return;
    }
    var medicine = _summary.first;
    final batch = TextEditingController();
    final quantity = TextEditingController();
    final cost = TextEditingController(text: '0');
    final selling = TextEditingController(text: '0');
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
                  items: _summary
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_text(item['medicineName'])),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => medicine = value ?? medicine,
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
    if (batch.text.trim().isEmpty || qty == null || qty <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter batch number and valid quantity.')),
        );
      }
      return;
    }
    await _run(() async {
      await _api.receive({
        'medicineId': _id(medicine['id']),
        'batchNumber': batch.text.trim(),
        'expiryDate': expiry?.toIso8601String().split('T').first,
        'quantity': qty,
        'costPrice': num.tryParse(cost.text) ?? 0,
        'sellingPrice': num.tryParse(selling.text) ?? 0,
        'notes': notes.text.trim(),
        'idempotencyKey': _key('receive'),
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
    if (qty == null || qty <= 0 || reason.text.trim().isEmpty) return;
    await _run(() async {
      await _api.adjust({
        'stockBatchId': _id(item['id']),
        'direction': direction,
        'quantity': qty,
        'reason': reason.text.trim(),
        'idempotencyKey': _key('adjust'),
      });
    });
  }

  Future<void> _dispense() async {
    if (_summary.isEmpty) return;
    var medicine = _summary.first;
    final prescriptionId = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dispense Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: prescriptionId,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Server prescription ID'),
            ),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: medicine,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Medicine'),
              items: _summary
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_text(item['medicineName'])),
                    ),
                  )
                  .toList(),
              onChanged: (value) => medicine = value ?? medicine,
            ),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
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
            child: const Text('Dispense'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final rxId = int.tryParse(prescriptionId.text);
    final qty = num.tryParse(quantity.text);
    if (rxId == null || rxId <= 0 || qty == null || qty <= 0) return;
    await _run(() async {
      final response = await _api.dispense({
        'prescriptionId': rxId,
        'items': [
          {'medicineId': _id(medicine['id']), 'quantity': qty},
        ],
        'idempotencyKey': _key('dispense'),
      });
      if (!mounted) return;
      final transactionId =
          response['dispenseTransactionId'] ?? response['transactionId'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispensed. Transaction ID: $transactionId')),
      );
    });
  }

  Future<void> _reverse() async {
    final transactionId = TextEditingController();
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
    await _run(() async {
      await _api.reverseDispense({
        'dispenseTransactionId': id,
        'reason': reason.text.trim(),
        'idempotencyKey': _key('reverse'),
      });
    });
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
    final totalQuantity = _summary.fold<num>(
      0,
      (sum, item) => sum + _number(item['availableQuantity']),
    );
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
    final low = _summary.where((x) => x['isLowStock'] == true).length;
    final expiry = _summary
        .where((x) => x['isExpired'] == true || x['isExpiringSoon'] == true)
        .length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    child: _metric('Medicines', '${_summary.length}',
                        Icons.medication, _green),
                  ),
                  SizedBox(
                    width: width < 104 ? constraints.maxWidth : width,
                    child: _metric(
                        'Low stock', '$low', Icons.warning_amber, Colors.orange),
                  ),
                  SizedBox(
                    width: width < 104 ? constraints.maxWidth : width,
                    child: _metric(
                        'Expiry alerts', '$expiry', Icons.event_busy, Colors.red),
                  ),
                ],
              );
            },
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
        ],
      ),
    );
  }

  Widget _batchList() => RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _batches.length,
          itemBuilder: (_, index) {
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
                onTap: () => _adjust(item),
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
                    const Text('Tap to adjust',
                        style: TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _movementList() => RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _movements.length,
          itemBuilder: (_, index) {
            final item = _movements[index];
            final quantity = _number(item['quantityChange']);
            final positive = quantity >= 0;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFD1E7DF)),
              ),
              child: ListTile(
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
                  '${_text(item['createdAt']).replaceFirst('T', ' ')}',
                ),
                isThreeLine: true,
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
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
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
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'dispense') _dispense();
                if (value == 'reverse') _reverse();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'dispense',
                  child: Text('Dispense prescription'),
                ),
                PopupMenuItem(
                  value: 'reverse',
                  child: Text('Reverse dispense'),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            dividerColor: Colors.white24,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Batches'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _receive,
          backgroundColor: _green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Receive Stock'),
        ),
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
