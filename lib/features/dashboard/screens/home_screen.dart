import 'package:flutter/material.dart';

import '../../auth/data/doctor_session.dart';
import '../../auth/screens/login_screen.dart';
import '../../dashboard/screens/dashboard_analytics_screen.dart';
import '../../license/data/license_api_service.dart';

import '../../opd/screens/opd_fast_mode_screen.dart';
import '../../patient/screens/patient_master_screen.dart';
import '../../queue/screens/doctor_queue_screen.dart';
import '../../prescription/screens/patient_history_screen.dart';
import '../../prescription/screens/prescription_history_screen.dart';
import '../../prescription/screens/prescription_list_screen.dart';
import '../../prescription/screens/qr_scan_screen.dart';
import '../../printer/screens/printer_screen.dart';
import '../../sync/services/network_service.dart';
import '../../sync/services/sync_service.dart';
import '../../medicines/screens/medicine_screen.dart';
import '../../net_service/connection_mode_service.dart';
import '../../net_service/api_config.dart';
import '../../net_service/auto_api_resolver.dart';
import '../../local_server/screens/doctor_hotspot_qr_screen.dart';
import '../../patient/data/api_patient_service.dart';
import 'dart:async';
import '../../license/screens/admin_subscription_screen.dart';

import '../../followup/screens/follow_up_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LicenseApiService _licenseApiService = LicenseApiService();
  

  bool _isSyncing = false;
  bool _isCheckingLicense = true;
  bool _licenseValid = true;

  String _licenseMessage = '';
  String _planName = '';
  int _daysRemaining = 0;
  bool _connectionOnline = false;
String _connectionMode = '';
String _activeBaseUrl = '';

Map<String, dynamic> _queueSummary = {
  'waiting': 0,
  'serving': 0,
  'completed': 0,
  'skipped': 0,
};
Timer? _summaryTimer;
 @override
void initState() {
  super.initState();
  _checkInternet();
  _refreshConnectionStatus();
  _checkLicenseOnDashboard();
  _loadQueueSummary();
 

  _summaryTimer = Timer.periodic(
  const Duration(seconds: 5),
  (_) {
    if (!mounted) return;

    _loadQueueSummary();
  },
);
}

  Future<void> _checkInternet() async {
    final online = await NetworkService.isOnline();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(online ? 'Internet ON ✅' : 'No Internet ❌')),
    );
  }

  Future<void> _checkLicenseOnDashboard() async {
    setState(() => _isCheckingLicense = true);

    try {
      final result = await _licenseApiService.getStatus();

      if (!mounted) return;

      if (result['success'] != true) {
        setState(() {
          _licenseValid = false;
          _licenseMessage = result['message']?.toString() ?? 'License expired';
          _isCheckingLicense = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(result['data'] as Map);

      final isActive = data['isActive'] == true;
      final isExpired = data['isExpired'] == true;
      final days = int.tryParse(data['daysRemaining']?.toString() ?? '0') ?? 0;

      setState(() {
        _licenseValid = isActive && !isExpired;
        _planName = data['planName']?.toString() ?? '';
        _daysRemaining = days;
        _licenseMessage = _licenseValid
            ? '$_planName active - $_daysRemaining days remaining'
            : 'License expired. Please renew subscription.';
        _isCheckingLicense = false;
      });

      if (_licenseValid && days <= 7) {
        _showExpiryWarning(days);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _licenseValid = false;
        _licenseMessage = 'License check failed: $e';
        _isCheckingLicense = false;
      });
    }
  }

  void _showExpiryWarning(int days) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('License Expiry Warning'),
            content: Text(
              days <= 0
                  ? 'Your license expires today. Please renew soon.'
                  : 'Your license will expire in $days day(s). Please renew soon.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _logout() async {
    await DoctorSession.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;

    final online = await NetworkService.isOnline();

    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet ❌')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing... 🔄')),
    );

    try {
      final result = await SyncService().syncAll();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
  result.hasFailures
      ? 'Sync error ❌ ${result.lastError}'
      : 'Synced ✅ Doctors: ${result.doctorSuccess}, Patients: ${result.patientSuccess}, Medicines: ${result.medicineSuccess}, Rx: ${result.prescriptionSuccess}, Pull P: ${result.pulledPatients}, Pull Med: ${result.pulledMedicines}, Pull Rx: ${result.pulledPrescriptions}',
),
        ),
      );

      await _checkLicenseOnDashboard();
      await _loadQueueSummary();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed ❌ $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _navigate(String title) {
    if (!_licenseValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License expired. Dashboard locked.')),
      );
      return;
    }

    Widget? screen;

    switch (title) {

      case 'Hotspot QR':
        screen = const DoctorHotspotQrScreen();
        break;

      case 'OPD Fast Mode':
        screen = const OPDFastModeScreen();
        break;
      case 'Analytics':
        screen = const DashboardAnalyticsScreen();
        break;
      case 'Medicines':
  screen = const MedicineScreen();
  break;
      case 'Create Prescription':
        screen = const PrescriptionListScreen();
        break;
      case 'Prescription History':
        screen = const PrescriptionHistoryScreen();
        break;
      case 'Patient History':
        screen = const PatientHistoryScreen();
        break;
      case 'Patient Master':
        screen = const PatientMasterScreen();
        break;
        case 'Today Queue':
  screen = const DoctorQueueScreen();
  break;
      case 'Scan Prescription':
        screen = const QRScanScreen();
        break;
      case 'Thermal Print Setup':
        screen = const PrinterScreen();
        break;
        
        case 'Admin Subscriptions':
  screen = const AdminSubscriptionScreen();
  break;
       

case 'Follow-Ups':
  screen = const FollowUpScreen();
  break;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  Future<void> _showConnectionModeDialog() async {
  String currentMode =
      ConnectionModeService.getCurrentMode();

  await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Connection Mode'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(
                  title: const Text('Auto'),
                  value: 'auto',
                  groupValue: currentMode,
                  onChanged: (v) async {
                    await ConnectionModeService
                        .setAutoMode();

                    setStateDialog(() {
                      currentMode = 'auto';
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Cloud'),
                  value: 'cloud',
                  groupValue: currentMode,
                  onChanged: (v) async {
                    await ConnectionModeService
                        .setCloudMode();

                    setStateDialog(() {
                      currentMode = 'cloud';
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Local WiFi'),
                  value: 'wifi',
                  groupValue: currentMode,
                  onChanged: (v) async {
                    await ConnectionModeService
                        .setLocalWifiMode();

                    setStateDialog(() {
                      currentMode = 'wifi';
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Doctor Hotspot'),
                  value: 'hotspot',
                  groupValue: currentMode,
                  onChanged: (v) async {
                    await ConnectionModeService
                        .setHotspotMode();

                    setStateDialog(() {
                      currentMode = 'hotspot';
                    });
                  },
                ),
                RadioListTile(
                  title: const Text('Offline Only'),
                  value: 'offline',
                  groupValue: currentMode,
                  onChanged: (v) async {
                    await ConnectionModeService
                        .setOfflineMode();

                    setStateDialog(() {
                      currentMode = 'offline';
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
  'Mode: ${currentMode.toUpperCase()}\n'
  'Active Base URL:\n${ApiConfig.baseUrl}',
  textAlign: TextAlign.center,
  style: const TextStyle(fontSize: 12),
),
const SizedBox(height: 10),
OutlinedButton.icon(
  onPressed: () async {
    await ConnectionModeService.setAutoMode();
    await AutoApiResolver.resolve();

    setStateDialog(() {
      currentMode = 'auto';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto detect refreshed'),
      ),
    );
  },
  icon: const Icon(Icons.refresh),
  label: const Text('Retry Auto Detect'),
),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
_refreshConnectionStatus();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Mode changed: $currentMode',
                      ),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _buildLicenseBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 60, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'License Expired',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _licenseMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _checkLicenseOnDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Again'),
                ),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _navigate(title),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _refreshConnectionStatus() async {
  final online = await NetworkService.isOnline();

  if (!mounted) return;

  setState(() {
    _connectionOnline = online;
    _connectionMode = ConnectionModeService.getCurrentMode();
    _activeBaseUrl = ApiConfig.baseUrl;
  });
}

Future<void> _loadQueueSummary() async {
  try {
    final summary = await ApiPatientService().getQueueSummary();

    if (!mounted) return;

    setState(() {
      _queueSummary = summary;
    });
  } catch (e) {
  debugPrint('Queue summary load failed: $e');
}
}



Widget _summaryCard(
  String title,
  String count,
  Color color,
  IconData icon,
) {
  return Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
    ),
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

 Widget _buildDashboard() {
  final items = [
    _buildCard('OPD Fast Mode', Icons.flash_on, Colors.red),
    _buildCard('Analytics', Icons.bar_chart, Colors.deepPurple),
    _buildCard(
  'Admin Subscriptions',
  Icons.workspace_premium,
  Colors.deepPurple,
),
    _buildCard('Medicines', Icons.medication, Colors.blue),
    _buildCard('Today Queue', Icons.queue, Colors.deepOrange),
    _buildCard('Follow-Ups', Icons.notifications_active, Colors.orange),
    _buildCard('Create Prescription', Icons.note_add, Colors.green),
    _buildCard('Prescription History', Icons.history, Colors.orange),
    _buildCard('Patient History', Icons.search, Colors.teal),
    _buildCard('Patient Master', Icons.people_alt, Colors.brown),
    _buildCard('Scan Prescription', Icons.qr_code_scanner, Colors.indigo),
    _buildCard('Thermal Print Setup', Icons.print, Colors.purple),
    _buildCard('Hotspot QR', Icons.qr_code_2, Colors.blueGrey),
  ];

  return Column(
    children: [

        // CONNECTION STATUS
    Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: _connectionOnline
            ? Colors.green.withOpacity(0.08)
            : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _connectionOnline
                ? Icons.cloud_done
                : Icons.cloud_off,
            size: 18,
            color:
                _connectionOnline
                    ? Colors.green
                    : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _connectionOnline
                  ? 'Online Mode'
                  : 'Offline Mode',
              style: TextStyle(
                color:
                    _connectionOnline
                        ? Colors.green
                        : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),

    // LICENSE STATUS
    Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: _daysRemaining <= 7
            ? Colors.orange.withOpacity(0.08)
            : Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user,
            size: 18,
            color:
                _daysRemaining <= 7
                    ? Colors.orange
                    : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_planName • $_daysRemaining days remaining',
              style: TextStyle(
                color:
                    _daysRemaining <= 7
                        ? Colors.orange
                        : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),

    // QUEUE SUMMARY
    

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            _summaryCard(
              'Waiting',
              _queueSummary['waiting'].toString(),
              Colors.orange,
              Icons.queue,
            ),
            _summaryCard(
              'Serving',
              _queueSummary['serving'].toString(),
              Colors.green,
              Icons.local_hospital,
            ),
            _summaryCard(
              'Completed',
              _queueSummary['completed'].toString(),
              Colors.blue,
              Icons.check_circle,
            ),
            _summaryCard(
              'Skipped',
              _queueSummary['skipped'].toString(),
              Colors.red,
              Icons.skip_next,
            ),
          ],
        ),
      ),

      

      


      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, index) => items[index],
        ),
      ),
    ],
  );
}

@override
void dispose() {
  _summaryTimer?.cancel();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    
    if (_isCheckingLicense) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    

    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
       actions: [
  IconButton(
    icon: const Icon(Icons.settings_ethernet),
    tooltip: 'Connection Mode',
    onPressed: _showConnectionModeDialog,
  ),
  IconButton(
    icon: const Icon(Icons.logout),
    onPressed: _logout,
  ),
],
      ),
      floatingActionButton: _licenseValid
          ? FloatingActionButton.extended(
              onPressed: _isSyncing ? null : _syncNow,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Syncing' : 'Sync'),
            )
          : null,
      body: _licenseValid ? _buildDashboard() : _buildLicenseBlock(),
    );
  }
}