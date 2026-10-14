import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DesktopBillingReportView extends StatelessWidget {
  const DesktopBillingReportView({
    super.key,
    required this.summary,
    required this.bills,
    required this.totalRecords,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.errorMessage,
    required this.dateRange,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.searchController,
    required this.scrollController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFiltersChanged,
    required this.onPickDateRange,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> bills;
  final int totalRecords;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final DateTimeRange dateRange;
  final String paymentStatus;
  final String paymentMethod;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(String status, String method) onFiltersChanged;
  final Future<void> Function() onPickDateRange;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) => 'Rs. ${_number(value).toStringAsFixed(2)}';
  String _text(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString().trim();

  (String, String) _formattedDateTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return ('-', '');
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return (raw, '');
    final local = parsed.toLocal();
    return (
      DateFormat('dd MMM yyyy').format(local),
      DateFormat('hh:mm a').format(local),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _header(),
              const SizedBox(height: 18),
              _summaryCards(),
              const SizedBox(height: 16),
              _filters(),
              const SizedBox(height: 14),
              Expanded(child: _content()),
            ]),
          ),
        ),
      );

  Widget _header() => Row(children: [
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Billing & Reports',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            SizedBox(height: 5),
            Text('Review income, payments and outstanding balances.',
                style: TextStyle(color: Color(0xFF64748B))),
          ]),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ]);

  Widget _summaryCards() => Row(children: [
        _summaryCard('Gross total', _money(summary['total_income']),
            Icons.account_balance_wallet_outlined, const Color(0xFF0F766E)),
        const SizedBox(width: 12),
        _summaryCard('Paid', _money(summary['paid_total']),
            Icons.payments_outlined, const Color(0xFF15803D)),
        const SizedBox(width: 12),
        _summaryCard('Outstanding', _money(summary['balance_total']),
            Icons.pending_actions_outlined, const Color(0xFFC2410C)),
        const SizedBox(width: 12),
        _summaryCard('Bills', '${summary['bill_count'] ?? 0}',
            Icons.receipt_long_outlined, const Color(0xFF2563EB)),
      ]);

  Widget _summaryCard(String title, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ])),
          ]),
        ),
      );

  Widget _filters() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search patient, Rx number or payment',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onPickDateRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              '${DateFormat('dd MMM yyyy').format(dateRange.start)} – '
              '${DateFormat('dd MMM yyyy').format(dateRange.end)}',
            ),
          ),
          const SizedBox(width: 10),
          _dropdown('Status', paymentStatus, const {
            'all': 'All statuses',
            'Paid': 'Paid',
            'Pending': 'Pending',
            'Partial': 'Partial',
          }, (value) => onFiltersChanged(value, paymentMethod)),
          const SizedBox(width: 10),
          _dropdown('Method', paymentMethod, const {
            'all': 'All methods',
            'Cash': 'Cash',
            'Card': 'Card',
            'Bank Transfer': 'Bank transfer',
          }, (value) => onFiltersChanged(paymentStatus, value)),
        ]),
      );

  Widget _dropdown(String label, String value, Map<String, String> choices,
          ValueChanged<String> changed) =>
      SizedBox(
        width: 155,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: choices.entries
              .map((x) => DropdownMenuItem(value: x.key, child: Text(x.value)))
              .toList(),
          onChanged: (next) {
            if (next != null) changed(next);
          },
        ),
      );

  Widget _content() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 54, color: Color(0xFFDC2626)),
          const SizedBox(height: 12),
          Text(errorMessage!, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again')),
        ]),
      );
    }
    if (bills.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 54, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('No bills found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 5),
          Text('Change the date range, search or payment filters.',
              style: TextStyle(color: Color(0xFF64748B))),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            Text('$totalRecords bill${totalRecords == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${bills.length} loaded',
                style: const TextStyle(color: Color(0xFF64748B))),
          ]),
        ),
        const Divider(height: 1),
        const _BillingHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: bills.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _billRow(bills[index]),
          ),
        ),
        if (isLoadingMore)
          const LinearProgressIndicator(minHeight: 2)
        else if (hasMore)
          Padding(
            padding: const EdgeInsets.all(9),
            child: TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load more bills')),
          ),
      ]),
    );
  }

  Widget _billRow(Map<String, dynamic> bill) {
    final patient = _text(bill, 'patient_name');
    final status = _text(bill, 'payment_status');
    final paid = status.toLowerCase() == 'paid';
    final dateTime = _formattedDateTime(bill['created_at']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        Expanded(flex: 17, child: Text(_text(bill, 'prescription_no').isEmpty ? '-' : _text(bill, 'prescription_no'), style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(flex: 20, child: Text(patient.isEmpty ? 'Patient unavailable' : patient, overflow: TextOverflow.ellipsis)),
        Expanded(
          flex: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateTime.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (dateTime.$2.isNotEmpty)
                Text(
                  dateTime.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
        Expanded(flex: 14, child: Text(_text(bill, 'payment_method').isEmpty ? '-' : _text(bill, 'payment_method'))),
        Expanded(flex: 13, child: Text(_money(bill['total_amount']))),
        Expanded(flex: 13, child: Text(_money(bill['paid_amount']))),
        Expanded(flex: 13, child: Text(_money(bill['balance_amount']))),
        Expanded(
          flex: 12,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.isEmpty ? 'Unknown' : status,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: paid ? const Color(0xFF15803D) : const Color(0xFFC2410C))),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BillingHeader extends StatelessWidget {
  const _BillingHeader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(children: [
          Expanded(flex: 17, child: Text('RX NUMBER')),
          Expanded(flex: 20, child: Text('PATIENT')),
          Expanded(flex: 18, child: Text('DATE')),
          Expanded(flex: 14, child: Text('METHOD')),
          Expanded(flex: 13, child: Text('TOTAL')),
          Expanded(flex: 13, child: Text('PAID')),
          Expanded(flex: 13, child: Text('BALANCE')),
          Expanded(flex: 12, child: Text('STATUS')),
        ]),
      );
}
