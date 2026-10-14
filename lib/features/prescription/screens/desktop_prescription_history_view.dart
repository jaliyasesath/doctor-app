import 'package:flutter/material.dart';

class DesktopPrescriptionHistoryView extends StatefulWidget {
  const DesktopPrescriptionHistoryView({
    super.key,
    required this.prescriptions,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.receptionMode,
    required this.scrollController,
    required this.onRefresh,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onLoadMore,
  });

  final List<Map<String, dynamic>> prescriptions;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool receptionMode;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(int) onEdit;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onLoadMore;

  @override
  State<DesktopPrescriptionHistoryView> createState() =>
      _DesktopPrescriptionHistoryViewState();
}

class _DesktopPrescriptionHistoryViewState
    extends State<DesktopPrescriptionHistoryView> {
  final _searchController = TextEditingController();
  String _syncFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _text(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString().trim();

  List<Map<String, dynamic>> get _visibleRows {
    final query = _searchController.text.trim().toLowerCase();
    return widget.prescriptions.where((row) {
      final sync = _text(row, 'sync_status').toLowerCase();
      final matchesSync = _syncFilter == 'all' || sync == _syncFilter;
      if (!matchesSync) return false;
      if (query.isEmpty) return true;
      return [
        _text(row, 'patient_name'),
        _text(row, 'prescription_no'),
        _text(row, 'diagnosis'),
        _text(row, 'prescription_date'),
        _text(row, 'id'),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 20),
              _summary(rows.length),
              const SizedBox(height: 16),
              _toolbar(),
              const SizedBox(height: 14),
              Expanded(child: _content(rows)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prescription History',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                SizedBox(height: 5),
                Text('Review, open and manage previous prescriptions.',
                    style: TextStyle(color: Color(0xFF64748B))),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: widget.isLoading ? null : widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      );

  Widget _summary(int visible) => Row(
        children: [
          _stat('Loaded', '${widget.prescriptions.length}', Icons.receipt_long),
          const SizedBox(width: 12),
          _stat('Visible', '$visible', Icons.visibility_outlined),
          const SizedBox(width: 12),
          _stat(
            'Cloud status',
            '${widget.prescriptions.where((x) => _text(x, 'sync_status') == 'synced').length} synced',
            Icons.cloud_done_outlined,
          ),
        ],
      );

  Widget _stat(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF0F766E), size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
            ]),
          ]),
        ),
      );

  Widget _toolbar() => Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search patient, Rx number, diagnosis or date',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            value: _syncFilter,
            decoration: InputDecoration(
              labelText: 'Sync status',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All records')),
              DropdownMenuItem(value: 'synced', child: Text('Synced')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
            ],
            onChanged: (value) =>
                setState(() => _syncFilter = value ?? 'all'),
          ),
        ),
      ]);

  Widget _content(List<Map<String, dynamic>> rows) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return _empty();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        const _HistoryTableHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _row(rows[index]),
          ),
        ),
        if (widget.isLoadingMore)
          const LinearProgressIndicator(minHeight: 2)
        else if (widget.hasMore)
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextButton.icon(
              onPressed: widget.onLoadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load more records'),
            ),
          ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final patient = _text(item, 'patient_name');
    final sync = _text(item, 'sync_status');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        Expanded(
          flex: 25,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient.isEmpty ? 'Unknown Patient' : patient,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Age ${_text(item, 'patient_age')} • ${_text(item, 'patient_gender')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
        ),
        Expanded(flex: 18, child: Text(_text(item, 'prescription_no').isEmpty ? '-' : _text(item, 'prescription_no'))),
        Expanded(flex: 18, child: Text(_text(item, 'prescription_date').isEmpty ? '-' : _text(item, 'prescription_date'))),
        Expanded(flex: 22, child: Text(_text(item, 'diagnosis').isEmpty ? '-' : _text(item, 'diagnosis'), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 10, child: _syncBadge(sync)),
        SizedBox(
          width: 112,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              tooltip: 'Open prescription',
              onPressed: () => widget.onOpen(item),
              icon: const Icon(Icons.visibility_outlined),
            ),
            if (widget.receptionMode)
              IconButton(
                tooltip: 'Edit prescription',
                onPressed: () => widget.onEdit(id),
                icon: const Icon(Icons.edit_outlined),
              )
            else
              IconButton(
                tooltip: 'Delete prescription',
                onPressed: () => widget.onDelete(id),
                color: const Color(0xFFDC2626),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _syncBadge(String value) {
    final synced = value.toLowerCase() == 'synced';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: synced ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(value.isEmpty ? 'Local' : value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: synced
                    ? const Color(0xFF15803D)
                    : const Color(0xFFC2410C))),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_outlined,
              size: 54, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text('No prescriptions found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          TextButton(onPressed: widget.onRefresh, child: const Text('Refresh')),
        ]),
      );
}

class _HistoryTableHeader extends StatelessWidget {
  const _HistoryTableHeader();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(children: [
          Expanded(flex: 25, child: Text('PATIENT')),
          Expanded(flex: 18, child: Text('RX NUMBER')),
          Expanded(flex: 18, child: Text('DATE')),
          Expanded(flex: 22, child: Text('DIAGNOSIS')),
          Expanded(flex: 10, child: Text('STATUS')),
          SizedBox(width: 112, child: Text('ACTIONS', textAlign: TextAlign.right)),
        ]),
      );
}
