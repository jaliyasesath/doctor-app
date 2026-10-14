import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';
import 'desktop_billing_report_view.dart';

class BillingReportScreen extends StatefulWidget {
  const BillingReportScreen({super.key});

  @override
  State<BillingReportScreen> createState() => _BillingReportScreenState();
}

class _BillingReportScreenState extends State<BillingReportScreen> {
  static const _green = Color(0xFF0F766E);
  static const _deepGreen = Color(0xFF064E3B);
  static const _surface = Color(0xFFF3F7F6);
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _loadError;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _bills = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  int? _doctorId;
  int _total = 0;
  int _offset = 0;
  static const int _limit = 50;
  String _paymentStatus = 'all';
  String _paymentMethod = 'all';
  late DateTimeRange _dateRange;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dateRange = DateTimeRange(start: today, end: today);
    _scrollController.addListener(_onScroll);
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 220 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      unawaited(_loadMore());
    }
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _loadReport() async {
    final generation = ++_loadGeneration;
    final doctorId = _doctorId ?? await DoctorSession.getDoctorId();

    if (doctorId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Doctor session not found. Please sign in again.';
      });
      return;
    }
    _doctorId = doctorId;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final from = _dateKey(_dateRange.start);
      final to = _dateKey(_dateRange.end);
      final results = await Future.wait<dynamic>([
        DatabaseHelper.instance.getBillingSummaryByDoctorRange(
          doctorId,
          dateFrom: from,
          dateTo: to,
          paymentStatus: _paymentStatus,
          paymentMethod: _paymentMethod,
        ),
        DatabaseHelper.instance.getBillsByDoctorRangePaged(
          doctorId,
          dateFrom: from,
          dateTo: to,
          query: _searchController.text,
          paymentStatus: _paymentStatus,
          paymentMethod: _paymentMethod,
          limit: _limit,
          offset: 0,
        ),
        DatabaseHelper.instance.countBillsByDoctorRange(
          doctorId,
          dateFrom: from,
          dateTo: to,
          query: _searchController.text,
          paymentStatus: _paymentStatus,
          paymentMethod: _paymentMethod,
        ),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      final bills = List<Map<String, dynamic>>.from(results[1] as List);
      setState(() {
        _summary = Map<String, dynamic>.from(results[0] as Map);
        _bills = bills;
        _total = results[2] as int;
        _offset = bills.length;
        _hasMore = _offset < _total;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Billing records could not be loaded.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_doctorId == null || !_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final rows = await DatabaseHelper.instance.getBillsByDoctorRangePaged(
        _doctorId!,
        dateFrom: _dateKey(_dateRange.start),
        dateTo: _dateKey(_dateRange.end),
        query: _searchController.text,
        paymentStatus: _paymentStatus,
        paymentMethod: _paymentMethod,
        limit: _limit,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _bills.addAll(rows);
        _offset += rows.length;
        _hasMore = _offset < _total;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('More billing records could not be loaded.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_loadReport()),
    );
  }

  void _applyFilters(String status, String method) {
    setState(() {
      _paymentStatus = status;
      _paymentMethod = method;
    });
    unawaited(_loadReport());
  }

  Future<void> _pickDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      useRootNavigator: false,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
    );
    if (selected == null || !mounted) return;
    setState(() => _dateRange = selected);
    await _loadReport();
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFFFE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE9E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: _green),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billCount = _summary['bill_count'] ?? 0;

    final totalIncome = _toDouble(_summary['total_income']);
    final consultationIncome = _toDouble(_summary['consultation_income']);
    final medicineIncome = _toDouble(_summary['medicine_income']);

    final useDesktopLayout =
        Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000;
    if (useDesktopLayout) {
      return DesktopBillingReportView(
        summary: _summary,
        bills: _bills,
        totalRecords: _total,
        isLoading: _isLoading,
        isLoadingMore: _isLoadingMore,
        hasMore: _hasMore,
        errorMessage: _loadError,
        dateRange: _dateRange,
        paymentStatus: _paymentStatus,
        paymentMethod: _paymentMethod,
        searchController: _searchController,
        scrollController: _scrollController,
        onSearchChanged: _onSearchChanged,
        onClearSearch: () {
          _searchController.clear();
          unawaited(_loadReport());
        },
        onFiltersChanged: _applyFilters,
        onPickDateRange: _pickDateRange,
        onRefresh: _loadReport,
        onLoadMore: _loadMore,
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: _deepGreen,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_deepGreen, _green, Color(0xFF22A06B)],
            ),
          ),
        ),
        title: const Text('Daily Income Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    DateTime.now().toString().substring(0, 10),
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _summaryCard(
                        title: 'Total Income',
                        value: 'Rs. ${totalIncome.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet,
                      ),
                      const SizedBox(width: 10),
                      _summaryCard(
                        title: 'Bills',
                        value: billCount.toString(),
                        icon: Icons.receipt_long,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _summaryCard(
                        title: 'Channeling',
                        value: 'Rs. ${consultationIncome.toStringAsFixed(2)}',
                        icon: Icons.person,
                      ),
                      const SizedBox(width: 10),
                      _summaryCard(
                        title: 'Medicine',
                        value: 'Rs. ${medicineIncome.toStringAsFixed(2)}',
                        icon: Icons.medication,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Today Bills',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_bills.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No bills found for today'),
                      ),
                    )
                  else
                    ..._bills.map((bill) {
                      final total = _toDouble(bill['total_amount']);
                      final paid = _toDouble(bill['paid_amount']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFFFE),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFDCE9E5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              color: _green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rx: ${bill['prescription_no'] ?? '-'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Payment: ${bill['payment_method'] ?? '-'} • ${bill['payment_status'] ?? '-'}',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs. ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Paid: Rs. ${paid.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
