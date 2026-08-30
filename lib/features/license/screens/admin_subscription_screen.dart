import 'package:flutter/material.dart';
import '../data/api_admin_subscription_service.dart';

class AdminSubscriptionScreen extends StatefulWidget {
  const AdminSubscriptionScreen({super.key});

  @override
  State<AdminSubscriptionScreen> createState() =>
      _AdminSubscriptionScreenState();
}

class _AdminSubscriptionScreenState extends State<AdminSubscriptionScreen> {
  final ApiAdminSubscriptionService _api = ApiAdminSubscriptionService();

  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final data = await _api.getDoctorsWithSubscription();

      if (!mounted) return;

      setState(() {
        _doctors = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _activate(int doctorId, String planName) async {
    try {
      await _api.activateSubscription(
        doctorId: doctorId,
        planName: planName,
      );

      await _loadDoctors();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$planName activated')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _extend(int doctorId, int months) async {
    try {
      await _api.extendSubscription(
        doctorId: doctorId,
        months: months,
      );

      await _loadDoctors();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extended by $months month(s)')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deactivate(int doctorId) async {
    try {
      await _api.deactivateSubscription(doctorId: doctorId);

      await _loadDoctors();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription deactivated')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }

  Color _statusColor(Map<String, dynamic>? sub) {
    if (sub == null) return Colors.grey;

    final canUseApp = sub['canUseApp'] == true;
    final isExpired = sub['isExpired'] == true;

    if (canUseApp) return Colors.green;
    if (isExpired) return Colors.red;

    return Colors.orange;
  }

  String _statusText(Map<String, dynamic>? sub) {
    if (sub == null) return 'No subscription';

    final canUseApp = sub['canUseApp'] == true;
    final isExpired = sub['isExpired'] == true;
    final isActive = sub['isActive'] == true;

    if (canUseApp) {
      return 'Active • ${sub['daysRemaining'] ?? 0} days left';
    }

    if (!isActive) return 'Inactive';
    if (isExpired) return 'Expired';

    return 'Unknown';
  }

  Map<String, dynamic>? _subOf(Map<String, dynamic> doctor) {
    final sub = doctor['subscription'];

    if (sub == null) return null;

    return Map<String, dynamic>.from(sub);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Subscriptions'),
        actions: [
          IconButton(
            onPressed: _loadDoctors,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : _doctors.isEmpty
                  ? const Center(child: Text('No doctors found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _doctors.length,
                      itemBuilder: (context, index) {
                        final doctor = _doctors[index];
                        final sub = _subOf(doctor);

                        final doctorId = doctor['doctorId'] as int;
                        final doctorName =
                            doctor['doctorName']?.toString() ?? 'Doctor';
                        final email = doctor['email']?.toString() ?? '';
                        final contact =
                            doctor['contactNumber']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doctorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          if (contact.isNotEmpty)
                                            Text(
                                              contact,
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _statusColor(sub).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _statusColor(sub).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    _statusText(sub),
                                    style: TextStyle(
                                      color: _statusColor(sub),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (sub != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Plan: ${sub['planName'] ?? '-'}',
                                  ),
                                  Text(
                                    'End Date: ${sub['endDate'] ?? '-'}',
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        _activate(doctorId, 'OneMonth');
                                      },
                                      child: const Text('Activate 1M'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        _activate(doctorId, 'OneYear');
                                      },
                                      child: const Text('Activate 1Y'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        _extend(doctorId, 1);
                                      },
                                      child: const Text('Extend 1M'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        _extend(doctorId, 12);
                                      },
                                      child: const Text('Extend 1Y'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _deactivate(doctorId);
                                      },
                                      child: const Text(
                                        'Deactivate',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
