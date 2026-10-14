import 'package:flutter/material.dart';

class DesktopLaboratoryListView extends StatefulWidget {
  const DesktopLaboratoryListView({
    super.key,
    required this.labs,
    required this.loading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onTestEmail,
  });

  final List<Map<String, dynamic>> labs;
  final bool loading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onAdd;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final Future<void> Function(Map<String, dynamic>) onTestEmail;

  @override
  State<DesktopLaboratoryListView> createState() =>
      _DesktopLaboratoryListViewState();
}

class _DesktopLaboratoryListViewState
    extends State<DesktopLaboratoryListView> {
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
    return widget.labs.where((lab) {
      final active = lab['isActive'] != false;
      if (_status == 'active' && !active) return false;
      if (_status == 'inactive' && active) return false;
      if (_status == 'favorite' && lab['isFavorite'] != true) return false;
      if (query.isEmpty) return true;
      return ['name', 'branchName', 'email', 'phone', 'address']
          .map((key) => _text(lab, key).toLowerCase())
          .any((value) => value.contains(query));
    }).toList(growable: false);
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
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Laboratories',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            SizedBox(height: 5),
            Text('Manage trusted laboratories and delivery contacts.',
                style: TextStyle(color: Color(0xFF64748B))),
          ]),
        ),
        OutlinedButton.icon(
          onPressed: widget.loading ? null : widget.onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: widget.onAdd,
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Register laboratory'),
        ),
      ]);

  Widget _summary() {
    final active = widget.labs.where((x) => x['isActive'] != false).length;
    final favorite = widget.labs.where((x) => x['isFavorite'] == true).length;
    return Row(children: [
      _stat('Registered', '${widget.labs.length}', Icons.science_outlined),
      const SizedBox(width: 12),
      _stat('Active', '$active', Icons.check_circle_outline_rounded),
      const SizedBox(width: 12),
      _stat('Favorites', '$favorite', Icons.star_outline_rounded),
    ]);
  }

  Widget _stat(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(width: 11),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
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
              hintText: 'Search laboratory, branch, email, phone or address',
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
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _status,
            decoration: InputDecoration(
                labelText: 'Filter',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All laboratories')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'favorite', child: Text('Favorites')),
            ],
            onChanged: (value) => setState(() => _status = value ?? 'all'),
          ),
        ),
      ]);

  Widget _content() {
    if (widget.loading) return const Center(child: CircularProgressIndicator());
    if (widget.errorMessage != null) {
      return _messageState(Icons.cloud_off_outlined, widget.errorMessage!,
          action: TextButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again')));
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return _messageState(Icons.science_outlined, 'No laboratories found');
    }
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        const _LaboratoryHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _row(rows[index]),
          ),
        ),
      ]),
    );
  }

  Widget _messageState(IconData icon, String message, {Widget? action}) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 54, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (action != null) ...[const SizedBox(height: 8), action],
        ]),
      );

  Widget _row(Map<String, dynamic> lab) {
    final active = lab['isActive'] != false;
    final favorite = lab['isFavorite'] == true;
    final name = _text(lab, 'name');
    final branch = _text(lab, 'branchName');
    return InkWell(
      onTap: () => widget.onEdit(lab),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(children: [
          Expanded(
            flex: 25,
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE6FFFB),
                child: Icon(favorite ? Icons.star_rounded : Icons.science_rounded,
                    color: const Color(0xFF0F766E)),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Unnamed laboratory' : name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (branch.isNotEmpty)
                  Text(branch,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
            ]),
          ),
          Expanded(flex: 20, child: Text(_text(lab, 'email').isEmpty ? '-' : _text(lab, 'email'), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 15, child: Text(_text(lab, 'phone').isEmpty ? '-' : _text(lab, 'phone'))),
          Expanded(flex: 22, child: Text(_text(lab, 'address').isEmpty ? '-' : _text(lab, 'address'), overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(active ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? const Color(0xFF15803D) : const Color(0xFF64748B))),
              ),
            ),
          ),
          SizedBox(
            width: 132,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                  tooltip: 'Send test email',
                  onPressed: () => widget.onTestEmail(lab),
                  icon: const Icon(Icons.mark_email_read_outlined)),
              IconButton(
                  tooltip: 'Edit laboratory',
                  onPressed: () => widget.onEdit(lab),
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  tooltip: 'Remove laboratory',
                  color: const Color(0xFFDC2626),
                  onPressed: () => widget.onDelete(lab),
                  icon: const Icon(Icons.delete_outline_rounded)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LaboratoryHeader extends StatelessWidget {
  const _LaboratoryHeader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(children: [
          Expanded(flex: 25, child: Text('LABORATORY')),
          Expanded(flex: 20, child: Text('EMAIL')),
          Expanded(flex: 15, child: Text('PHONE')),
          Expanded(flex: 22, child: Text('ADDRESS')),
          Expanded(flex: 10, child: Text('STATUS')),
          SizedBox(width: 132, child: Text('ACTIONS', textAlign: TextAlign.right)),
        ]),
      );
}
