import 'package:flutter/material.dart';
import 'dart:async';
import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import '../../prescription/screens/print_preview_screen.dart';

class ReceptionBillsScreen extends StatefulWidget {
  const ReceptionBillsScreen({super.key});

  @override
  State<ReceptionBillsScreen> createState() => _ReceptionBillsScreenState();
}

class _ReceptionBillsScreenState extends State<ReceptionBillsScreen> {
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _allBills = [];
  List<Map<String, dynamic>> _filteredBills = [];

  @override
  void initState() {
    super.initState();

    _loadBills(showLoader: true);

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _loadBills();
      },
    );
  }

  Future<void> _loadBills({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    final doctorId = await DoctorSession.getDoctorId();

    if (doctorId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final data = await DatabaseHelper.instance.getAllBills();

    if (!mounted) return;

    final currentSearch = _searchController.text.trim().toLowerCase();

    setState(() {
      _allBills = List<Map<String, dynamic>>.from(data);

      if (currentSearch.isEmpty) {
        _filteredBills = _allBills;
      } else {
        _filteredBills = _allBills.where((bill) {
          final rx = bill['prescription_no']?.toString().toLowerCase() ?? '';

          final patientId = bill['patient_id']?.toString().toLowerCase() ?? '';

          final amount = bill['total_amount']?.toString().toLowerCase() ?? '';

          return rx.contains(currentSearch) ||
              patientId.contains(currentSearch) ||
              amount.contains(currentSearch);
        }).toList();
      }

      _loading = false;
    });
  }

  void _filterBills(String value) {
    final q = value.trim().toLowerCase();

    setState(() {
      _filteredBills = _allBills.where((bill) {
        final rx = bill['prescription_no']?.toString().toLowerCase() ?? '';

        final patientId = bill['patient_id']?.toString().toLowerCase() ?? '';

        final amount = bill['total_amount']?.toString().toLowerCase() ?? '';

        return rx.contains(q) || patientId.contains(q) || amount.contains(q);
      }).toList();
    });
  }

  Widget _billCard(Map<String, dynamic> bill) {
    final rxNo = bill['prescription_no']?.toString() ?? '-';
    final total = (bill['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (bill['paid_amount'] as num?)?.toDouble() ?? 0;
    final method = bill['payment_method']?.toString() ?? '-';
    final status = bill['payment_status']?.toString() ?? '-';
    final createdAt = bill['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.receipt_long),
        ),
        title: Text(
          'Rx: $rxNo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Total: Rs. ${total.toStringAsFixed(2)}\n'
          'Paid: Rs. ${paid.toStringAsFixed(2)}\n'
          'Method: $method • $status\n'
          '${createdAt.isEmpty ? '' : createdAt.substring(0, 10)}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.print),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrintPreviewScreen(
                  passedRxNo: rxNo,
                  passedDate: createdAt.isEmpty
                      ? DateTime.now().toString().substring(0, 10)
                      : createdAt.substring(0, 10),
                  allowBillSave: false,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Reception Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBills,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Rx No / Patient ID / Amount',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterBills,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBills.isEmpty
                    ? const Center(child: Text('No bills found'))
                    : RefreshIndicator(
                        onRefresh: _loadBills,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredBills.length,
                          itemBuilder: (_, index) {
                            return _billCard(
                              _filteredBills[index],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
