import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_error_ui.dart';
import '../../../data/local/database_helper.dart';

import '../../auth/data/doctor_session.dart';
import '../../dashboard/screens/dashboard_analytics_screen.dart';
import '../../license/data/license_api_service.dart';
import '../../opd/screens/opd_fast_mode_screen.dart';
import '../../patient/screens/patient_master_screen.dart';
import '../../queue/screens/doctor_queue_screen.dart';
import '../../queue/services/queue_realtime_service.dart';
import '../../queue/services/queue_sync_service.dart';
import '../../prescription/screens/patient_history_screen.dart';
import '../../prescription/screens/prescription_history_screen.dart';
import '../../prescription/screens/prescription_list_screen.dart';
import '../../prescription/screens/qr_scan_screen.dart';
import '../../sync/services/network_service.dart';
import '../../sync/services/sync_service.dart';
import '../../medicines/screens/medicine_screen.dart';
import '../../net_service/connection_mode_service.dart';
import '../../net_service/api_config.dart';
import '../../net_service/auto_api_resolver.dart';
import '../../local_server/screens/doctor_hotspot_qr_screen.dart';
import '../../patient/data/api_patient_service.dart';
import '../../followup/screens/follow_up_screen.dart';
import '../../billing/screens/billing_report_screen.dart';
import '../../license/screens/license_gate_screen.dart';
import '../../license/data/license_service.dart';
import '../../reception/screens/manage_reception_accounts_screen.dart';
import '../../stock/screens/medicine_stock_screen.dart';
import '../../lab/screens/laboratory_list_screen.dart';
import '../../profile/screens/doctor_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primaryGreen = Color(0xFF0F766E);
  static const Color _deepGreen = Color(0xFF064E3B);
  static const Color _freshGreen = Color(0xFF22A06B);
  static const Color _ink = Color(0xFF14213D);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _surface = Color(0xFFF4F8F7);

  final LicenseApiService _licenseApiService = LicenseApiService();

  bool _isSyncing = false;
  bool _isCheckingLicense = true;
  bool _licenseValid = true;

  String _licenseMessage = '';
  String _planName = '';
  int _daysRemaining = 0;

  bool _connectionOnline = false;
  String _connectionMode = '';

  String _doctorName = 'Doctor';

  Timer? _licenseTimer;
  StreamSubscription<Map<String, dynamic>>? _queueEventSubscription;

  Map<String, dynamic> _queueSummary = {
    'waiting': 0,
    'serving': 0,
    'completed': 0,
    'skipped': 0,
  };

  Map<String, dynamic> _todayIncome = {
    'bill_count': 0,
    'total_income': 0,
    'consultation_income': 0,
    'medicine_income': 0,
    'paid_total': 0,
    'balance_total': 0,
  };

  int _todayFollowUpCount = 0;
  int _pendingSyncCount = 0;

  List<Map<String, dynamic>> _recentPrescriptions = [];

  @override
  void initState() {
    super.initState();

    _loadDoctorName();
    _checkInternet();
    _refreshAll();
    _queueEventSubscription = QueueRealtimeService.instance.events.listen((_) {
      if (!mounted) return;
      unawaited(_loadQueueSummary());
    });
    unawaited(QueueRealtimeService.instance.connect());
    unawaited(QueueSyncService.instance.syncChanges());

    _licenseTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        _checkLicenseOnDashboard();
      },
    );
  }

  Future<void> _refreshAll() async {
    await _refreshConnectionStatus();
    await _checkLicenseOnDashboard();
    await _loadQueueSummary();
    await _loadDashboardLocalData();
  }

  Future<void> _loadDoctorName() async {
    final name = await DoctorSession.getDoctorName();

    if (!mounted) return;

    setState(() {
      _doctorName = name?.isNotEmpty == true ? name! : 'Doctor';
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _getFormattedToday() {
    final now = DateTime.now();

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _getHeaderMessage() {
    final waiting =
        int.tryParse(_queueSummary['waiting']?.toString() ?? '0') ?? 0;

    final serving =
        int.tryParse(_queueSummary['serving']?.toString() ?? '0') ?? 0;

    if (waiting > 0) {
      return 'Welcome back. You have $waiting patient(s) waiting in the queue.';
    }

    if (serving > 0) {
      return 'Welcome back. You are currently serving $serving patient(s).';
    }

    return 'Welcome back. Your queue is clear.';
  }

  Future<void> _checkInternet() async {
    final online = await NetworkService.isOnline();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(online ? 'Internet ON ✅' : 'No Internet ❌'),
      ),
    );
  }

  Future<void> _checkLicenseOnDashboard() async {
    if (!_licenseValid) {
      setState(() => _isCheckingLicense = true);
    }

    final trialExpired = await LicenseService.isTrialExpired();

    if (trialExpired) {
      setState(() {
        _licenseValid = false;
        _licenseMessage = 'Trial expired. Please activate subscription.';
        _isCheckingLicense = false;
      });
      return;
    }

    try {
      final result = await _licenseApiService.getStatus();

      if (!mounted) return;

      if (result['success'] != true) {
        final cachedValid = await LicenseService.isCachedSubscriptionValid();

        if (cachedValid) {
          final cached = await LicenseService.getCachedSubscription();

          setState(() {
            _licenseValid = true;
            _planName = cached['planName']?.toString() ?? 'Cached';
            _daysRemaining =
                int.tryParse(cached['daysRemaining']?.toString() ?? '0') ?? 0;
            _licenseMessage =
                'Offline license active - $_daysRemaining days remaining';
            _isCheckingLicense = false;
          });

          return;
        }

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

      final endDateRaw = data['endDate']?.toString();
      final endDate = endDateRaw == null ? null : DateTime.tryParse(endDateRaw);

      if (isActive && !isExpired && endDate != null) {
        await LicenseService.saveSubscriptionCache(
          planName: data['planName']?.toString() ?? '',
          endDate: endDate,
          daysRemaining: days,
        );
      }

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

      final cachedValid = await LicenseService.isCachedSubscriptionValid();

      if (cachedValid) {
        final cached = await LicenseService.getCachedSubscription();

        setState(() {
          _licenseValid = true;
          _planName = cached['planName']?.toString() ?? 'Cached';
          _daysRemaining =
              int.tryParse(cached['daysRemaining']?.toString() ?? '0') ?? 0;
          _licenseMessage =
              'Offline license active - $_daysRemaining days remaining';
          _isCheckingLicense = false;
        });

        return;
      }

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
    await QueueRealtimeService.instance.disconnect();
    await DoctorSession.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LicenseGateScreen()),
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
                : 'Synced ✅ Doctors: ${result.doctorSuccess}, Patients: ${result.patientSuccess}, Medicines: ${result.medicineSuccess}, Rx: ${result.prescriptionSuccess}',
          ),
        ),
      );

      await _refreshAll();
    } catch (e) {
      if (!mounted) return;

      AppErrorUi.show(
        context,
        e,
        onRetry: _syncNow,
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
      case 'Create Prescription':
        screen = const PrescriptionListScreen();
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
      case 'Medicine Stock':
        screen = const MedicineStockScreen();
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
      case 'Follow-Ups':
        screen = const FollowUpScreen();
        break;
      case 'Income Report':
        screen = const BillingReportScreen();
        break;
      case 'Hotspot QR':
        screen = const DoctorHotspotQrScreen();
        break;
      case 'Reception Accounts':
        screen = const ManageReceptionAccountsScreen();
        break;
      case 'Laboratories':
        screen = const LaboratoryListScreen();
        break;
      case 'Doctor Profile':
        screen = const DoctorProfileScreen();
        break;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  Future<void> _showConnectionModeDialog() async {
    String currentMode = ConnectionModeService.getCurrentMode();

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Connection Mode'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile(
                      title: const Text('Auto'),
                      value: 'auto',
                      groupValue: currentMode,
                      onChanged: (v) async {
                        await ConnectionModeService.setAutoMode();
                        setStateDialog(() => currentMode = 'auto');
                      },
                    ),
                    RadioListTile(
                      title: const Text('Cloud'),
                      value: 'cloud',
                      groupValue: currentMode,
                      onChanged: (v) async {
                        await ConnectionModeService.setCloudMode();
                        setStateDialog(() => currentMode = 'cloud');
                      },
                    ),
                    RadioListTile(
                      title: const Text('Local WiFi'),
                      value: 'wifi',
                      groupValue: currentMode,
                      onChanged: (v) async {
                        await ConnectionModeService.setLocalWifiMode();
                        setStateDialog(() => currentMode = 'wifi');
                      },
                    ),
                    RadioListTile(
                      title: const Text('Doctor Hotspot'),
                      value: 'hotspot',
                      groupValue: currentMode,
                      onChanged: (v) async {
                        await ConnectionModeService.setHotspotMode();
                        setStateDialog(() => currentMode = 'hotspot');
                      },
                    ),
                    RadioListTile(
                      title: const Text('Offline Only'),
                      value: 'offline',
                      groupValue: currentMode,
                      onChanged: (v) async {
                        await ConnectionModeService.setOfflineMode();
                        setStateDialog(() => currentMode = 'offline');
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mode: ${currentMode.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ConnectionModeService.setAutoMode();
                        await AutoApiResolver.resolve();

                        setStateDialog(() => currentMode = 'auto');

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
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _refreshConnectionStatus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Mode changed: $currentMode')),
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

  Future<void> _refreshConnectionStatus() async {
    final online = await NetworkService.isOnline();

    if (!mounted) return;

    setState(() {
      _connectionOnline = online;
      _connectionMode = ConnectionModeService.getCurrentMode();
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

  Future<void> _loadDashboardLocalData() async {
    try {
      final doctorId = await DoctorSession.getDoctorId();

      if (doctorId == null) return;

      final income =
          await DatabaseHelper.instance.getTodayIncomeSummaryByDoctor(doctorId);

      final followUps =
          await DatabaseHelper.instance.getTodayFollowUps(doctorId: doctorId);

      final recent =
          await DatabaseHelper.instance.getPrescriptionsByDoctorPaged(
        doctorId,
        limit: 5,
        offset: 0,
      );

      final pendingPatients =
          await DatabaseHelper.instance.getPendingPatients();

      final pendingMedicines =
          await DatabaseHelper.instance.getPendingMedicines();

      final pendingPrescriptions =
          await DatabaseHelper.instance.getPendingPrescriptions();

      final pendingBills = await DatabaseHelper.instance.getPendingBills();

      if (!mounted) return;

      setState(() {
        _todayIncome = income;
        _todayFollowUpCount = followUps.length;
        _recentPrescriptions = recent;
        _pendingSyncCount = pendingPatients.length +
            pendingMedicines.length +
            pendingPrescriptions.length +
            pendingBills.length;
      });
    } catch (e) {
      debugPrint('Dashboard local data load failed: $e');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE4ECE9)),
      boxShadow: [
        BoxShadow(
          color: _deepGreen.withOpacity(0.055),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
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
                Text(_licenseMessage, textAlign: TextAlign.center),
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

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B),
            Color(0xFF0B6B61),
            Color(0xFF22A06B),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          Positioned(
            top: -80,
            right: -65,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -75,
            child: Container(
              width: 165,
              height: 165,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: _primaryGreen,
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()},',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Dr. $_doctorName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _headerActionButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Connection settings',
                      onTap: _showConnectionModeDialog,
                    ),
                    const SizedBox(width: 8),
                    _headerActionButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Logout',
                      onTap: _logout,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _getFormattedToday(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getHeaderMessage(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _statusPill(
                        icon: _connectionOnline
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        text: _connectionOnline
                            ? 'Cloud Mode • Online'
                            : 'Offline Mode Active',
                        color: _connectionOnline
                            ? Colors.greenAccent
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statusPill(
                        icon: Icons.verified_user,
                        text: '$_planName • $_daysRemaining days',
                        color:
                            _daysRemaining <= 7 ? Colors.orange : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _statusPill(
                  icon: Icons.sync,
                  text: _pendingSyncCount == 0
                      ? 'All data synced'
                      : '$_pendingSyncCount record(s) pending sync',
                  color: _pendingSyncCount == 0
                      ? Colors.greenAccent
                      : Colors.amber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryPrescriptionButton() {
    return InkWell(
      onTap: () => _navigate('Today Queue'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F766E),
              Color(0xFF168A70),
              Color(0xFF22A06B),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F766E).withOpacity(0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Icon(
                Icons.groups_rounded,
                color: _primaryGreen,
                size: 31,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today Queue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View and manage today’s patients',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _queueSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Queue Summary",
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _navigate('Today Queue'),
                child: const Text('View Queue'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _queueMini(
                'Waiting',
                _queueSummary['waiting'].toString(),
                Icons.groups,
                Color(0xFFD97706),
              ),
              _queueMini(
                'Serving',
                _queueSummary['serving'].toString(),
                Icons.person,
                _freshGreen,
              ),
              _queueMini(
                'Completed',
                _queueSummary['completed'].toString(),
                Icons.check_circle,
                _primaryGreen,
              ),
              _queueMini(
                'Skipped',
                _queueSummary['skipped'].toString(),
                Icons.close,
                Color(0xFFDC5A5A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _queueMini(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.075),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: _mutedText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _mutedText),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _featureScroll(List<Widget> items) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          return SizedBox(
            width: MediaQuery.of(context).size.width - 96,
            child: items[index],
          );
        },
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 125,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.055),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.11),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 30),
          ],
        ),
      ),
    );
  }

  String _formatRecentDate(dynamic value) {
    if (value == null) return '';

    final raw = value.toString();
    final date = DateTime.tryParse(raw);

    if (date == null) return raw;

    final now = DateTime.now();

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Today $hour:$minute';
    }

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _safeText(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Widget _recentActivitySection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE8F5F1),
                child: Icon(Icons.trending_up, color: _primaryGreen),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Latest prescriptions and visits',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigate('Prescription History'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_recentPrescriptions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: Colors.black38,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No recent prescriptions found',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._recentPrescriptions.map((rx) {
              final rxNo = _safeText(rx['prescription_no'], 'RX');
              final patientName = _safeText(rx['patient_name'], 'Patient');
              final diagnosis = _safeText(rx['diagnosis'], 'No diagnosis');
              final complaint = _safeText(rx['complaint'], '');
              final date = _formatRecentDate(
                rx['created_at'] ?? rx['prescription_date'],
              );

              return InkWell(
                onTap: () => _navigate('Prescription History'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _primaryGreen.withOpacity(0.09),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    rxNo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (date.isNotEmpty) ...[
                                  const Text(
                                    ' • ',
                                    style: TextStyle(color: Colors.black38),
                                  ),
                                  Flexible(
                                    child: Text(
                                      date,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              complaint.isNotEmpty
                                  ? '$diagnosis • $complaint'
                                  : diagnosis,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final totalIncome = _toDouble(_todayIncome['total_income']);

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _headerCard(),
            _primaryPrescriptionButton(),
            const SizedBox(height: 8),
            _queueSummaryCard(),
            _sectionCard(
              title: "Today's Operations",
              icon: Icons.star,
              color: _primaryGreen,
              subtitle: 'Top priority',
              children: [
                _featureScroll([
                  _featureCard(
                    title: 'Create Prescription',
                    subtitle: 'Start a new prescription',
                    icon: Icons.note_add,
                    color: _primaryGreen,
                    onTap: () => _navigate('Create Prescription'),
                  ),
                  _featureCard(
                    title: 'Follow-Ups',
                    subtitle: '$_todayFollowUpCount due today',
                    icon: Icons.notifications_active,
                    color: const Color(0xFFD69E2E),
                    onTap: () => _navigate('Follow-Ups'),
                  ),
                  _featureCard(
                    title: 'Billing / Income',
                    subtitle: 'Rs. ${totalIncome.toStringAsFixed(2)} today',
                    icon: Icons.account_balance_wallet,
                    color: _freshGreen,
                    onTap: () => _navigate('Income Report'),
                  ),
                  _featureCard(
                    title: 'Sync Now',
                    subtitle: _pendingSyncCount == 0
                        ? 'All data synced'
                        : '$_pendingSyncCount pending',
                    icon: Icons.sync,
                    color: _primaryGreen,
                    onTap: _syncNow,
                  ),
                ]),
              ],
            ),
            _sectionCard(
              title: 'Patient Management',
              icon: Icons.people_alt,
              color: _primaryGreen,
              subtitle: 'Patients',
              children: [
                _featureScroll([
                  _featureCard(
                    title: 'Patients',
                    subtitle: 'Add, edit and manage patient records',
                    icon: Icons.groups,
                    color: _primaryGreen,
                    onTap: () => _navigate('Patient Master'),
                  ),
                  _featureCard(
                    title: 'Patient History',
                    subtitle: 'View patient treatment and visit history',
                    icon: Icons.person_search,
                    color: _freshGreen,
                    onTap: () => _navigate('Patient History'),
                  ),
                ]),
              ],
            ),
            _sectionCard(
              title: 'Clinical',
              icon: Icons.assignment,
              color: _primaryGreen,
              subtitle: 'Records',
              children: [
                _featureScroll([
                  _featureCard(
                    title: 'Medicines',
                    subtitle: 'Manage medicine master data',
                    icon: Icons.medication,
                    color: _primaryGreen,
                    onTap: () => _navigate('Medicines'),
                  ),
                  _featureCard(
                    title: 'Medicine Stock',
                    subtitle: 'Batches, stock levels and dispensing',
                    icon: Icons.inventory_2,
                    color: _deepGreen,
                    onTap: () => _navigate('Medicine Stock'),
                  ),
                  _featureCard(
                    title: 'Prescription History',
                    subtitle: 'View all prescription records',
                    icon: Icons.history,
                    color: _freshGreen,
                    onTap: () => _navigate('Prescription History'),
                  ),
                ]),
              ],
            ),
            _recentActivitySection(),
            _sectionCard(
              title: 'Tools',
              icon: Icons.construction,
              color: _primaryGreen,
              subtitle: 'Utilities',
              children: [
                _featureScroll([
                  _featureCard(
                    title: 'QR Scan',
                    subtitle: 'Scan prescription QR code',
                    icon: Icons.qr_code_scanner,
                    color: _primaryGreen,
                    onTap: () => _navigate('Scan Prescription'),
                  ),
                  _featureCard(
                    title: 'OPD Fast Mode',
                    subtitle: 'Quick OPD consultation mode',
                    icon: Icons.flash_on,
                    color: const Color(0xFFE05D5D),
                    onTap: () => _navigate('OPD Fast Mode'),
                  ),
                  _featureCard(
                    title: 'Hotspot QR',
                    subtitle: 'Share hotspot connection QR',
                    icon: Icons.qr_code_2,
                    color: const Color(0xFF4F7C74),
                    onTap: () => _navigate('Hotspot QR'),
                  ),
                  _featureCard(
                    title: 'Analytics',
                    subtitle: 'Reports and clinic insights',
                    icon: Icons.bar_chart,
                    color: _freshGreen,
                    onTap: () => _navigate('Analytics'),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 95),
          ],
        ),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        _navigate('Today Queue');
        break;
      case 2:
        _navigate('Create Prescription');
        break;
      case 3:
        _navigate('Income Report');
        break;
      case 4:
        _showMoreSheet();
        break;
    }
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'More Options',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.people_alt),
                title: const Text('Patients'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Patient Master');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_search),
                title: const Text('Patient History'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Patient History');
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Prescription History'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Prescription History');
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('QR Scan'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Scan Prescription');
                },
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Laboratories'),
                subtitle: const Text('Register and manage referral laboratories'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Laboratories');
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Professional Profile'),
                subtitle: const Text('Doctor and medical centre details'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Doctor Profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync Now'),
                onTap: () {
                  Navigator.pop(context);
                  _syncNow();
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Reception Accounts'),
                subtitle: const Text('Add and manage linked reception users'),
                onTap: () {
                  Navigator.pop(context);
                  _navigate('Reception Accounts');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_ethernet),
                title: const Text('Connection Mode'),
                onTap: () {
                  Navigator.pop(context);
                  _showConnectionModeDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_queueEventSubscription?.cancel());
    _licenseTimer?.cancel();
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
      backgroundColor: _surface,
      body: _licenseValid ? _buildDashboard() : _buildLicenseBlock(),
      floatingActionButton: _licenseValid
          ? FloatingActionButton(
              backgroundColor: _primaryGreen,
              onPressed: () => _navigate('Create Prescription'),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _licenseValid
          ? BottomAppBar(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 12,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _bottomItem(Icons.home, 'Home', 0),
                    _bottomItem(Icons.queue, 'Queue', 1),
                    const SizedBox(width: 48),
                    _bottomItem(Icons.account_balance_wallet, 'Billing', 3),
                    _bottomItem(Icons.more_horiz, 'More', 4),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    final selected = index == 0;

    return InkWell(
      onTap: () => _onBottomNavTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? _primaryGreen : _mutedText,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? _primaryGreen : _mutedText,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
