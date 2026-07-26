import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../data/reception_account_service.dart';

class ManageReceptionAccountsScreen extends StatefulWidget {
  const ManageReceptionAccountsScreen({super.key});

  @override
  State<ManageReceptionAccountsScreen> createState() =>
      _ManageReceptionAccountsScreenState();
}

class _ManageReceptionAccountsScreenState
    extends State<ManageReceptionAccountsScreen> {
  static const _green = Color(0xFF0F766E);
  static const _deepGreen = Color(0xFF064E3B);
  static const _surface = Color(0xFFF4F8F7);

  final _service = ReceptionAccountService();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _message(Object error) {
    if (error is AppException) return error.userMessage;
    return 'Something went wrong. Please try again.';
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final accounts = await _service.getAccounts();
      if (!mounted) return;
      setState(() => _accounts = accounts);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _strongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  Future<void> _addAccount() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    bool submitting = false;
    bool obscure = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() => submitting = true);

            try {
              await _service.createAccount(
                name: name.text.trim(),
                email: email.text.trim(),
                contactNumber: phone.text.trim(),
                password: password.text,
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Reception account created successfully.'),
                  backgroundColor: _green,
                ),
              );
              await _load();
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() => submitting = false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(_message(error))),
              );
            }
          }

          return AlertDialog(
            title: const Text('Add Reception Account'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Reception name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter the reception name.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(text)
                            ? null
                            : 'Enter a valid email.';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the contact number.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Temporary password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) => _strongPassword(value ?? '')
                          ? null
                          : 'Use 8+ characters with upper, lower, number and symbol.',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Give this email and temporary password privately to your reception user.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    submitting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                style: FilledButton.styleFrom(backgroundColor: _green),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ],
          );
        },
      ),
    );

    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
  }

  Future<void> _changeStatus(Map<String, dynamic> account) async {
    final current = account['status']?.toString() ?? 'Approved';
    final next = current == 'Approved' ? 'Suspended' : 'Approved';
    final verb = next == 'Approved' ? 'reactivate' : 'suspend';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verb[0].toUpperCase()}${verb.substring(1)} account?'),
        content: Text(
          next == 'Approved'
              ? 'This reception user will be able to log in again.'
              : 'This reception user will be logged out and cannot log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: next == 'Approved' ? _green : Colors.red,
            ),
            child: Text(next == 'Approved' ? 'Reactivate' : 'Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.updateStatus(
        receptionId: account['id'] as int,
        status: next,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> account) async {
    final controller = TextEditingController();
    bool obscure = true;

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset Reception Password'),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'New temporary password',
              helperText: '8+ chars: upper, lower, number and symbol',
              suffixIcon: IconButton(
                onPressed: () => setDialogState(() => obscure = !obscure),
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!_strongPassword(controller.text)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Password is not strong enough.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, controller.text);
              },
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;

    try {
      await _service.resetPassword(
        receptionId: account['id'] as int,
        newPassword: value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset. Existing sessions were revoked.'),
          backgroundColor: _green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Widget _accountCard(Map<String, dynamic> account) {
    final status = account['status']?.toString() ?? 'Suspended';
    final active = status == 'Approved';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDDE9E5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: active
                      ? const Color(0xFFD9F5E9)
                      : const Color(0xFFFEE2E2),
                  child: Icon(
                    Icons.support_agent,
                    color: active ? _green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account['name']?.toString() ?? 'Reception',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        account['email']?.toString() ?? '',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(active ? 'Active' : 'Suspended'),
                  backgroundColor: active
                      ? const Color(0xFFD9F5E9)
                      : const Color(0xFFFEE2E2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(account['contactNumber']?.toString() ?? ''),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _resetPassword(account),
                  icon: const Icon(Icons.password),
                  label: const Text('Reset Password'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _changeStatus(account),
                  icon: Icon(active ? Icons.block : Icons.check_circle_outline),
                  label: Text(active ? 'Suspend' : 'Reactivate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: active ? Colors.red : _green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Reception Accounts'),
        foregroundColor: Colors.white,
        backgroundColor: _deepGreen,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAccount,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Reception'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _accounts.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'No reception accounts yet.\\nSelect Add Reception to create one.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _accounts.length,
                        itemBuilder: (_, index) =>
                            _accountCard(_accounts[index]),
                      ),
                    ),
    );
  }
}
