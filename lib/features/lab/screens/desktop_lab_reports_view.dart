import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DesktopLabReportsView extends StatefulWidget {
  const DesktopLabReportsView({
    super.key,
    required this.reports,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.openingId,
    required this.patientName,
    required this.scrollController,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    required this.onReview,
  });

  final List<Map<String, dynamic>> reports;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int? openingId;
  final String patientName;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(Map<String, dynamic>, String) onReview;

  @override
  State<DesktopLabReportsView> createState() => _DesktopLabReportsViewState();
}

class _DesktopLabReportsViewState extends State<DesktopLabReportsView> {
  final _search = TextEditingController();
  String _status = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _text(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString().trim();

  List<Map<String, dynamic>> get _visible {
    final query = _search.text.trim().toLowerCase();
    return widget.reports.where((report) {
      final status = _text(report, 'status').toLowerCase();
      if (_status != 'all' && status != _status) return false;
      if (query.isEmpty) return true;
      return ['originalFileName', 'patientName', 'laboratoryName', 'laboratoryNotes']
          .map((key) => _text(report, key).toLowerCase())
          .any((value) => value.contains(query));
    }).toList(growable: false);
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
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
              _summary(),
              const SizedBox(height: 16),
              _toolbar(),
              const SizedBox(height: 14),
              Expanded(child: _content()),
            ]),
          ),
        ),
      );

  Widget _header() => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Laboratory Reports',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 5),
            Text(
              widget.patientName.isEmpty
                  ? 'Review laboratory results and request corrections.'
                  : 'Reports for ${widget.patientName}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ]),
        ),
        OutlinedButton.icon(
          onPressed: widget.loading ? null : widget.onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ]);

  Widget _summary() {
    int count(String status) => widget.reports
        .where((x) => _text(x, 'status').toLowerCase() == status)
        .length;
    return Row(children: [
      _stat('Loaded', '${widget.reports.length}', Icons.description_outlined),
      const SizedBox(width: 12),
      _stat('Awaiting review', '${count('uploaded')}', Icons.pending_actions_outlined),
      const SizedBox(width: 12),
      _stat('Reviewed', '${count('reviewed')}', Icons.check_circle_outline_rounded),
      const SizedBox(width: 12),
      _stat('Correction', '${count('rejected')}', Icons.report_problem_outlined),
    ]);
  }

  Widget _stat(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF0F766E)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          ]),
        ),
      );

  Widget _toolbar() => Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search patient, laboratory, file name or notes',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            value: _status,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: 'Review status',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All reports')),
              DropdownMenuItem(value: 'uploaded', child: Text('Awaiting review')),
              DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
              DropdownMenuItem(
                value: 'rejected',
                child: Text(
                  'Correction requested',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) => setState(() => _status = value ?? 'all'),
          ),
        ),
      ]);

  Widget _content() {
    if (widget.loading) return const Center(child: CircularProgressIndicator());
    final rows = _visible;
    if (rows.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.science_outlined, size: 54, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('No laboratory reports found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        const _LabReportHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _row(rows[index]),
          ),
        ),
        if (widget.loadingMore)
          const LinearProgressIndicator(minHeight: 2)
        else if (widget.hasMore)
          Padding(
            padding: const EdgeInsets.all(9),
            child: TextButton.icon(
                onPressed: widget.onLoadMore,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load more reports')),
          ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> report) {
    final id = (report['id'] as num?)?.toInt();
    final status = _text(report, 'status').isEmpty ? 'Uploaded' : _text(report, 'status');
    final reviewed = status.toLowerCase() == 'reviewed';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        Expanded(flex: 24, child: Text(_text(report, 'originalFileName').isEmpty ? 'Lab report' : _text(report, 'originalFileName'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(flex: 18, child: Text(_text(report, 'patientName').isEmpty ? (widget.patientName.isEmpty ? '-' : widget.patientName) : _text(report, 'patientName'), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 18, child: Text(_text(report, 'laboratoryName').isEmpty ? '-' : _text(report, 'laboratoryName'), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 18, child: Text(_date(report['uploadedAt']))),
        Expanded(flex: 12, child: _statusBadge(status)),
        SizedBox(
          width: 142,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
                tooltip: 'View report',
                onPressed: widget.openingId == id ? null : () => widget.onOpen(report),
                icon: widget.openingId == id
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.visibility_outlined)),
            IconButton(
                tooltip: 'Mark reviewed',
                onPressed: reviewed ? null : () => widget.onReview(report, 'Reviewed'),
                color: const Color(0xFF15803D),
                icon: const Icon(Icons.check_circle_outline_rounded)),
            IconButton(
                tooltip: 'Request correction',
                onPressed: () => widget.onReview(report, 'Rejected'),
                color: const Color(0xFFC2410C),
                icon: const Icon(Icons.report_problem_outlined)),
          ]),
        ),
      ]),
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final color = normalized == 'reviewed'
        ? const Color(0xFF15803D)
        : normalized == 'rejected'
            ? const Color(0xFFC2410C)
            : const Color(0xFF2563EB);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

class _LabReportHeader extends StatelessWidget {
  const _LabReportHeader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(children: [
          Expanded(flex: 24, child: Text('REPORT')),
          Expanded(flex: 18, child: Text('PATIENT')),
          Expanded(flex: 18, child: Text('LABORATORY')),
          Expanded(flex: 18, child: Text('UPLOADED')),
          Expanded(flex: 12, child: Text('STATUS')),
          SizedBox(width: 142, child: Text('ACTIONS', textAlign: TextAlign.right)),
        ]),
      );
}
