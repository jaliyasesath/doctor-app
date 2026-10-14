import 'package:flutter/material.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_error_ui.dart';
import '../../../core/widgets/desktop_module_shell.dart';
import '../data/reception_account_service.dart';

/// Windows-only account management. Existing mobile UI remains separate.
class DesktopReceptionAccountsScreen extends StatefulWidget {
  const DesktopReceptionAccountsScreen({super.key});

  @override
  State<DesktopReceptionAccountsScreen> createState() =>
      _DesktopReceptionAccountsScreenState();
}

class _DesktopReceptionAccountsScreenState
    extends State<DesktopReceptionAccountsScreen> {
  final _service = ReceptionAccountService();
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _filtered = [];
  String _status = 'All';
  Object? _error;
  bool _loading = false;
  bool _loaded = false;
  bool _mutating = false;
  bool _dialogOpen = false;
  int _page = 0;
  static const _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  int? _id(Map<String, dynamic> account) =>
      int.tryParse('${account['id'] ?? ''}');
  String _text(Map<String, dynamic> account, String field) =>
      account[field]?.toString() ?? '';
  bool _active(Map<String, dynamic> account) =>
      _text(account, 'status') == 'Approved';
  bool get _busy => _loading || _mutating || _dialogOpen;

  void _filter() {
    final query = _search.text.trim().toLowerCase();
    _filtered = _accounts.where((account) {
      final matchesStatus = _status == 'All' ||
          (_status == 'Active' && _active(account)) ||
          (_status == 'Suspended' &&
              _text(account, 'status') == 'Suspended');
      return matchesStatus && (query.isEmpty ||
          ['name', 'email', 'contactNumber'].any(
              (field) => _text(account, field).toLowerCase().contains(query)));
    }).toList(growable: false);
    _page = 0;
  }

  Future<void> _load() async {
    if (_loading || _mutating || !mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final accounts = await _service.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loaded = true;
        _filter();
      });
    } catch (error, stack) {
      // ApiClient already records API exceptions. Never log form values.
      if (error is! AppException) {
        AppErrorHandler.recordUnawaited(
          StateError('Reception account response could not be loaded.'), stack,
          source: 'DesktopReceptionAccounts', context: 'Load');
      }
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _strong(String value) => value.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[a-z]').hasMatch(value) &&
      RegExp(r'[0-9]').hasMatch(value) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  Future<void> _form({Map<String, dynamic>? account, bool reset = false}) async {
    if (_busy) return;
    final id = account == null ? null : _id(account);
    if (account != null && (id == null || id <= 0)) {
      _message('This account has an invalid identifier. Refresh and retry.');
      return;
    }
    setState(() => _dialogOpen = true);
    final name = TextEditingController(text: account?['name']?.toString() ?? '');
    final email = TextEditingController(text: account?['email']?.toString() ?? '');
    final phone = TextEditingController(text: account?['contactNumber']?.toString() ?? '');
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool obscure = true;
    bool saved = false;
    String? formError;
    final title = reset ? 'Reset password' : account == null ? 'Add reception account' : 'Edit reception account';
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) {
            Future<void> submit() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) return;
              update(() { saving = true; formError = null; });
              setState(() => _mutating = true);
              try {
                if (reset) {
                  await _service.resetPassword(receptionId: id!, newPassword: password.text);
                } else if (account == null) {
                  await _service.createAccount(name: name.text.trim(), email: email.text.trim(),
                      contactNumber: phone.text.trim(), password: password.text);
                } else {
                  await _service.updateAccount(receptionId: id!, name: name.text.trim(),
                      email: email.text.trim(), contactNumber: phone.text.trim());
                }
                saved = true;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error, stack) {
                if (error is! AppException) {
                  AppErrorHandler.recordUnawaited(StateError('Reception account action failed.'),
                      stack, source: 'DesktopReceptionAccounts', context: title);
                }
                if (dialogContext.mounted) {
                  update(() {
                    saving = false;
                    formError = account != null && !reset && error is AppException &&
                            (error.statusCode == 404 || error.statusCode == 405)
                        ? 'Account editing is not available on this API version. Ask the administrator to enable the account-update endpoint.'
                        : AppErrorHandler.messageFor(error);
                  });
                }
              } finally {
                if (mounted) setState(() => _mutating = false);
              }
            }
            return PopScope(
              canPop: !saving,
              child: AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Form(key: formKey, child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reset) Text('Reset the password for ${_text(account!, 'name')}? Existing sessions will be affected according to server policy.'),
                        if (!reset) ...[
                          TextFormField(controller: name, enabled: !saving,
                            maxLength: 120,
                            decoration: const InputDecoration(labelText: 'Reception name'),
                            validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter at least 2 characters.' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: email, enabled: !saving,
                            maxLength: 254, keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email.'),
                          const SizedBox(height: 12),
                          TextFormField(controller: phone, enabled: !saving,
                            maxLength: 30, keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Contact number'),
                            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a contact number.' : null),
                        ],
                        if (reset || account == null) ...[
                          const SizedBox(height: 12),
                          TextFormField(controller: password, enabled: !saving,
                            obscureText: obscure, enableSuggestions: false, autocorrect: false,
                            decoration: InputDecoration(labelText: 'Temporary password',
                              helperText: '8+ characters: upper, lower, number and symbol',
                              helperMaxLines: 2,
                              suffixIcon: IconButton(onPressed: saving ? null : () => update(() => obscure = !obscure),
                                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off))),
                            validator: (v) => _strong(v ?? '') ? null : 'Use a stronger password.'),
                        ],
                        if (formError != null) ...[
                          const SizedBox(height: 16),
                          Text(formError!, style: const TextStyle(color: Color(0xFF9F2D2D))),
                        ],
                      ],
                    )),
                  ),
                ),
                actions: [
                  TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                  FilledButton(onPressed: saving ? null : submit,
                    child: saving ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)) : Text(reset ? 'Confirm reset' : 'Save')),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      name.dispose(); email.dispose(); phone.dispose(); password.dispose();
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (saved && mounted) {
      _message(reset ? 'Password reset successfully.' : 'Account saved successfully.');
      await _load();
    }
  }

  Future<void> _statusAction(Map<String, dynamic> account) async {
    if (_busy) return;
    final id = _id(account);
    final current = _text(account, 'status');
    if (id == null || id <= 0 || !['Approved', 'Suspended'].contains(current)) {
      _message('This account cannot be changed. Refresh and check its status.');
      return;
    }
    final enable = !_active(account);
    setState(() => _dialogOpen = true);
    bool confirmed = false;
    try {
      confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text(enable ? 'Enable account?' : 'Disable account?'),
        content: Text('${_text(account, 'name')}\n\n${enable ? 'Allow this reception user to sign in again.' : 'Suspend this reception account. Session revocation is enforced by the server.'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(enable ? 'Enable' : 'Disable')),
        ],
      )) ?? false;
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (!confirmed || !mounted) return;
    setState(() => _mutating = true);
    bool saved = false;
    try {
      await _service.updateStatus(receptionId: id, status: enable ? 'Approved' : 'Suspended');
      saved = true;
    } catch (error, stack) {
      if (error is! AppException) {
        AppErrorHandler.recordUnawaited(StateError('Reception status update failed.'), stack,
            source: 'DesktopReceptionAccounts', context: 'Status');
      }
      if (mounted) AppErrorUi.show(context, error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
    if (saved && mounted) {
      _message(enable ? 'Account enabled.' : 'Account disabled.');
      await _load();
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _cell(String value, double width) => SizedBox(width: width,
      child: Tooltip(message: value, child: Text(value.isEmpty ? '—' : value,
        maxLines: 1, overflow: TextOverflow.ellipsis)));

  Widget _table() {
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length).toInt();
    final visible = _filtered.sublist(start, end);
    return Scrollbar(controller: _horizontal, thumbVisibility: true,
      child: SingleChildScrollView(controller: _horizontal, scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F7F5)),
          columnSpacing: 22, dataRowMinHeight: 56, dataRowMaxHeight: 64,
          columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Email')),
            DataColumn(label: Text('Contact')), DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions'))],
          rows: visible.map((account) {
            final status = _text(account, 'status');
            final valid = (_id(account) ?? 0) > 0;
            final enabled = !_busy && valid;
            return DataRow(cells: [
              DataCell(_cell(_text(account, 'name'), 160)),
              DataCell(_cell(_text(account, 'email'), 220)),
              DataCell(_cell(_text(account, 'contactNumber'), 125)),
              DataCell(Chip(label: Text(_active(account) ? 'Active' : status.isEmpty ? 'Unknown' : status),
                backgroundColor: _active(account) ? const Color(0xFFD9F5E9) : const Color(0xFFF1F5F9))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Edit account', onPressed: enabled ? () => _form(account: account) : null,
                  icon: const Icon(Icons.edit_outlined)),
                IconButton(tooltip: 'Reset password', onPressed: enabled ? () => _form(account: account, reset: true) : null,
                  icon: const Icon(Icons.password)),
                TextButton(onPressed: enabled && ['Approved', 'Suspended'].contains(status)
                    ? () => _statusAction(account) : null, child: Text(_active(account) ? 'Disable' : 'Enable')),
              ])),
            ]);
          }).toList(growable: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopModuleShell.canvas,
      body: DesktopModuleShell(
        embedded: true, title: 'Reception Accounts',
        subtitle: 'Manage clinic reception access', icon: Icons.support_agent,
        onBack: () => Navigator.maybePop(context),
        body: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              Chip(label: Text('Total: ${_accounts.length}')),
              Chip(label: Text('Active: ${_accounts.where(_active).length}')),
              Chip(label: Text('Suspended: ${_accounts.where((a) => _text(a, 'status') == 'Suspended').length}')),
            ]),
            const SizedBox(height: 16),
            DesktopPanel(padding: const EdgeInsets.all(16), child: Wrap(
              spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 320, child: TextField(controller: _search,
                  decoration: const InputDecoration(labelText: 'Search name, email or contact',
                    prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onChanged: (_) => setState(_filter))),
                SizedBox(width: 165, child: DropdownButtonFormField<String>(value: _status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: ['All', 'Active', 'Suspended'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (s) { if (s != null) setState(() { _status = s; _filter(); }); })),
                OutlinedButton.icon(onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh), label: const Text('Refresh')),
                FilledButton.icon(onPressed: _busy ? null : () => _form(),
                  icon: const Icon(Icons.person_add_alt_1), label: const Text('Add account')),
              ],
            )),
            const SizedBox(height: 16),
            if (_loading || _mutating) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              DesktopPanel(padding: const EdgeInsets.all(20), child: Column(children: [
                Text(AppErrorHandler.messageFor(_error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _busy ? null : _load, child: const Text('Retry')),
                if (_loaded) const Text('Previously loaded accounts are shown below.'),
              ])),
              const SizedBox(height: 12),
            ],
            if (_loaded && _filtered.isEmpty)
              DesktopPanel(padding: const EdgeInsets.all(40), child: Text(
                _accounts.isEmpty ? 'No reception accounts yet. Add an account to get started.'
                    : 'No accounts match your search and status filter.', textAlign: TextAlign.center)),
            if (_filtered.isNotEmpty) ...[
              DesktopPanel(child: _table()),
              const SizedBox(height: 12),
              Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${_page * _pageSize + 1}–${(_page * _pageSize + _pageSize).clamp(0, _filtered.length)} of ${_filtered.length} accounts'),
                IconButton(tooltip: 'Previous page', onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left)),
                IconButton(tooltip: 'Next page', onPressed: (_page + 1) * _pageSize < _filtered.length
                    ? () => setState(() => _page++) : null, icon: const Icon(Icons.chevron_right)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
