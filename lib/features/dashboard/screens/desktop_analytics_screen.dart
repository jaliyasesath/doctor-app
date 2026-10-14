import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/widgets/desktop_module_shell.dart';
import '../data/desktop_analytics_service.dart';

class DesktopAnalyticsScreen extends StatefulWidget {
  const DesktopAnalyticsScreen({super.key});
  @override
  State<DesktopAnalyticsScreen> createState() => _DesktopAnalyticsScreenState();
}

class _DesktopAnalyticsScreenState extends State<DesktopAnalyticsScreen> {
  final _service = DesktopAnalyticsService();
  final _money = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
  final _integer = NumberFormat.decimalPattern();
  late DateTime _from;
  late DateTime _to;
  DesktopAnalyticsSnapshot? _data;
  bool _loading = false;
  bool _picking = false;
  bool _incomeChart = true;
  String? _error;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = DateTime(now.year, now.month, now.day - 6);
    _load();
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    setState(() { _loading = true; _error = null; _data = null; });
    try {
      final result = await _service.load(_from, _to);
      if (!mounted) return;
      setState(() { _data = result; _loadedAt = DateTime.now(); });
    } catch (_, stack) {
      // Never log SQL values, patient records or account details.
      AppErrorHandler.recordUnawaited(StateError('Desktop analytics loading failed.'),
          stack, source: 'DesktopAnalytics', context: 'Load aggregate summaries');
      if (mounted) setState(() => _error =
          'Analytics could not be loaded. Check your signed-in account and retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preset(String value) async {
    if (_loading || _picking) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _to = today;
      switch (value) {
        case 'Today': _from = today; break;
        case 'Last 7 days': _from = DateTime(today.year, today.month, today.day - 6); break;
        case 'Last 30 days': _from = DateTime(today.year, today.month, today.day - 29); break;
        case 'This month': _from = DateTime(today.year, today.month); break;
      }
    });
    await _load();
  }

  Future<void> _chooseRange() async {
    if (_loading || _picking) return;
    setState(() => _picking = true);
    DateTimeRange? picked;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      picked = await showDateRangePicker(context: context,
        firstDate: DateTime(1900), lastDate: today,
        initialDateRange: DateTimeRange(start: _from, end: _to),
        helpText: 'Choose up to 366 days');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (picked == null || !mounted) return;
    final days = DateTime.utc(picked.end.year, picked.end.month, picked.end.day)
        .difference(DateTime.utc(picked.start.year, picked.start.month, picked.start.day)).inDays + 1;
    if (days > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a range of no more than 366 days.')));
      return;
    }
    final chosen = picked;
    setState(() { _from = chosen.start; _to = chosen.end; });
    await _load();
  }

  Widget _card(String label, String value, String explanation, IconData icon) {
    return DesktopPanel(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [Icon(icon, color: DesktopModuleShell.teal),
          const SizedBox(width: 10), Expanded(child: Text(label,
            style: const TextStyle(color: DesktopModuleShell.muted)))]),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800,
          color: DesktopModuleShell.ink)),
        const SizedBox(height: 8),
        Text(explanation, style: const TextStyle(fontSize: 12, color: DesktopModuleShell.muted)),
      ],
    ));
  }

  Widget _cards(DesktopAnalyticsSnapshot data) {
    String count(String key) => _integer.format(data.value(data.summary, key));
    String amount(String key) => _money.format(data.value(data.billing, key));
    final cards = [
      _card('Billed total', amount('billed'), 'Bills created in the selected period', Icons.receipt_long),
      _card('Collected on these bills', amount('collected'), 'Current paid amounts, including later payments', Icons.payments_outlined),
      _card('Outstanding on these bills', amount('outstanding'), 'Current balance for the selected bills', Icons.account_balance_wallet_outlined),
      _card('Prescriptions', count('prescriptions'), 'Active prescriptions in this period', Icons.description_outlined),
      _card('Patients treated', count('patients'), 'Distinct patient IDs with prescriptions', Icons.people_outline),
      _card('New patient records', count('new_patients'), 'Active patient records created in this period', Icons.person_add_alt),
      _card('Medicines prescribed', count('prescribed_medicines'), 'Distinct medicine names in prescriptions', Icons.medication_outlined),
      _card('Medicine lines', count('medicine_lines'), 'Prescription item rows, not units sold', Icons.list_alt),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1150 ? 4 : constraints.maxWidth >= 620 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (final card in cards) SizedBox(width: width, child: card),
      ]);
    });
  }

  /// At most 14 date buckets, including zero-activity days. No unbounded UI rows.
  List<Map<String, Object>> _buckets(DesktopAnalyticsSnapshot data) {
    final size = (data.daily.length / 14).ceil();
    final result = <Map<String, Object>>[];
    for (var start = 0; start < data.daily.length; start += size) {
      final end = (start + size).clamp(0, data.daily.length).toInt();
      num total = 0;
      for (var index = start; index < end; index++) {
        total += data.value(data.daily[index], _incomeChart ? 'collected' : 'prescriptions');
      }
      final from = data.daily[start]['day'].toString();
      final to = data.daily[end - 1]['day'].toString();
      result.add({'label': from == to ? from : '$from → $to', 'value': total});
    }
    return result;
  }

  Widget _bar(String label, num amount, num maximum, String formatted,
      {String? detail}) {
    final fraction = maximum <= 0 ? 0.0 : (amount / maximum).clamp(0.0, 1.0).toDouble();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(label: '$label: $formatted${detail == null ? '' : ', $detail'}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 12), Text(formatted)]),
          const SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
            minHeight: 10, value: fraction, color: DesktopModuleShell.teal,
            backgroundColor: const Color(0xFFEAF1F0))),
          if (detail != null) ...[const SizedBox(height: 4),
            Text(detail, style: const TextStyle(fontSize: 12, color: DesktopModuleShell.muted))],
        ]),
      ));
  }

  Widget _trend(DesktopAnalyticsSnapshot data) {
    final buckets = _buckets(data);
    final maximum = buckets.fold<num>(0, (max, row) => (row['value'] as num) > max ? row['value'] as num : max);
    return DesktopPanel(padding: const EdgeInsets.all(22), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Activity over time', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          ChoiceChip(label: const Text('Collected on bills'), selected: _incomeChart,
            onSelected: (_) => setState(() => _incomeChart = true)),
          ChoiceChip(label: const Text('Prescriptions'), selected: !_incomeChart,
            onSelected: (_) => setState(() => _incomeChart = false)),
        ]),
        const SizedBox(height: 8),
        Text(_incomeChart ? 'Grouped by bill creation date; this is not a payment-date cash-flow report.'
            : 'Prescriptions grouped by their recorded dates.',
          style: const TextStyle(fontSize: 12, color: DesktopModuleShell.muted)),
        const SizedBox(height: 12),
        if (maximum == 0) const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('No activity for this chart in the selected period.')),
        for (final bucket in buckets) _bar(bucket['label'] as String,
          bucket['value'] as num, maximum, _incomeChart
            ? _money.format(bucket['value']) : _integer.format(bucket['value'])),
      ],
    ));
  }

  Widget _medicines(DesktopAnalyticsSnapshot data) {
    final top = data.topMedicines;
    final maximum = top.fold<num>(0, (max, row) => data.value(row, 'lines') > max ? data.value(row, 'lines') : max);
    return DesktopPanel(padding: const EdgeInsets.all(22), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Top prescribed medicines', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Top 10 by prescription item rows. Names are grouped without case or surrounding spaces.',
          style: TextStyle(fontSize: 12, color: DesktopModuleShell.muted)),
        const SizedBox(height: 12),
        if (top.isEmpty) const Padding(padding: EdgeInsets.all(18),
          child: Text('No prescribed medicines in this period.')),
        for (final row in top) _bar('${row['name']}', data.value(row, 'lines'), maximum,
          '${_integer.format(data.value(row, 'lines'))} lines',
          detail: '${_integer.format(data.value(row, 'prescriptions'))} prescriptions'),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final dateFormat = DateFormat('dd MMM yyyy');
    return Scaffold(backgroundColor: DesktopModuleShell.canvas,
      body: DesktopModuleShell(embedded: true, title: 'Analytics',
        subtitle: 'Clinical activity and billing overview', icon: Icons.analytics_outlined,
        onBack: () => Navigator.maybePop(context),
        body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DesktopPanel(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${dateFormat.format(_from)} – ${dateFormat.format(_to)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final preset in ['Today', 'Last 7 days', 'Last 30 days', 'This month'])
                    OutlinedButton(onPressed: _loading || _picking ? null : () => _preset(preset), child: Text(preset)),
                  FilledButton.icon(onPressed: _loading || _picking ? null : _chooseRange,
                    icon: const Icon(Icons.date_range), label: const Text('Custom range')),
                  OutlinedButton.icon(onPressed: _loading || _picking ? null : _load,
                    icon: const Icon(Icons.refresh), label: const Text('Refresh')),
                ]),
                const SizedBox(height: 12),
                const Text('This device’s local data, including pending sync. Refresh reloads local summaries; sync completes through the existing app flow.',
                  style: TextStyle(fontSize: 12, color: DesktopModuleShell.muted)),
                if (_loadedAt != null && data != null) Text('Updated ${DateFormat('HH:mm:ss').format(_loadedAt!)}',
                  style: const TextStyle(fontSize: 12, color: DesktopModuleShell.muted)),
              ],
            )),
            const SizedBox(height: 20),
            if (_loading) const DesktopPanel(padding: EdgeInsets.all(48),
              child: Center(child: Column(children: [CircularProgressIndicator(),
                SizedBox(height: 16), Text('Loading analytics…')]))),
            if (_error != null) DesktopPanel(padding: const EdgeInsets.all(32),
              child: Column(children: [const Icon(Icons.error_outline, size: 36, color: Color(0xFF9F2D2D)),
                const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))])),
            if (data != null) ...[
              if (data.empty) ...[const DesktopPanel(padding: EdgeInsets.all(24),
                child: Text('No active prescriptions, new patients or bills in this date range. Try another range.')),
                const SizedBox(height: 16)],
              _cards(data),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 900) return Column(children: [
                  _trend(data), const SizedBox(height: 20), _medicines(data)]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: _trend(data)), const SizedBox(width: 20),
                  Expanded(flex: 2, child: _medicines(data))]);
              }),
            ],
          ],
        )),
      ));
  }
}
