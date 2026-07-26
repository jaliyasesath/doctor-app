import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../auth/data/doctor_session.dart';

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

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _bills = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _loadReport() async {
    final doctorId = await DoctorSession.getDoctorId();

    if (doctorId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final summary =
        await DatabaseHelper.instance.getTodayIncomeSummaryByDoctor(doctorId);

    final bills = await DatabaseHelper.instance.getTodayBillsByDoctor(doctorId);

    if (!mounted) return;

    setState(() {
      _summary = summary;
      _bills = bills;
      _isLoading = false;
    });
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
    final paidTotal = _toDouble(_summary['paid_total']);

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
