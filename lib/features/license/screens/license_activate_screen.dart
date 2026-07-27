import 'package:flutter/material.dart';
import '../data/license_service.dart';

class LicenseActivateScreen extends StatefulWidget {
  const LicenseActivateScreen({super.key});

  @override
  State<LicenseActivateScreen> createState() => _LicenseActivateScreenState();
}

class _LicenseActivateScreenState extends State<LicenseActivateScreen> {
  final TextEditingController _licenseController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _licenseController.text.trim();

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter license key')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await LicenseService.activateLicense(key);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result == 'invalid_key') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid license key')),
      );
      return;
    }

    if (result == 'already_bound' ||
        result == 'already_bound_to_other_device') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This license is already bound to another device'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('License activated successfully')),
    );

    Navigator.pop(context, true);
  }

  void _refreshSubscription() {
    Navigator.pop(context, true);
  }

  void _showPlanMessage(String plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$plan selected. Please contact admin after payment.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate License'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 56,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Activate License',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _licenseController,
                        decoration: InputDecoration(
                          labelText: 'License Key',
                          hintText: 'Ex: DOCAPP-LIFE-2026',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _activate,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lock_open),
                          label: const Text('Activate License'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 14),
                      const Text(
                        'Subscription Plans',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For monthly or yearly subscription, please contact admin after payment. Then tap Refresh Subscription.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _showPlanMessage('Monthly Plan');
                              },
                              icon: const Icon(Icons.calendar_month),
                              label: const Text('Monthly'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _showPlanMessage('Yearly Plan');
                              },
                              icon: const Icon(Icons.event_available),
                              label: const Text('Yearly'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _refreshSubscription,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Subscription'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
