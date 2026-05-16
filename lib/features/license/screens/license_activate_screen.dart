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

    setState(() {
      _isLoading = true;
    });

    final result = await LicenseService.activateLicense(key);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result == 'invalid_key') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid license key')),
      );
      return;
    }

    if (result == 'already_bound_to_other_device') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This license is already bound to another device',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('License activated successfully')),
    );

    Navigator.pop(context, true);
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
                      'Enter Lifetime License Key',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _licenseController,
                      decoration: InputDecoration(
                        labelText: 'License Key',
                        hintText: 'Ex: xxx',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _activate,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Activate'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}