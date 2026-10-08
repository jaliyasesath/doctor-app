import 'package:flutter/material.dart';

import '../../features/billing/screens/billing_report_screen.dart';
import '../../features/dashboard/screens/dashboard_analytics_screen.dart';
import '../../features/followup/screens/follow_up_screen.dart';
import '../../features/lab/screens/laboratory_list_screen.dart';
import '../../features/lab/screens/patient_lab_reports_screen.dart';
import '../../features/medicines/screens/medicine_screen.dart';
import '../../features/patient/screens/patient_master_screen.dart';
import '../../features/prescription/screens/patient_history_screen.dart';
import '../../features/prescription/screens/prescription_history_screen.dart';
import '../../features/prescription/screens/prescription_list_screen.dart';
import '../../features/profile/screens/doctor_profile_screen.dart';
import '../../features/queue/screens/doctor_queue_screen.dart';
import '../../features/reception/screens/manage_reception_accounts_screen.dart';
import '../../features/stock/screens/medicine_stock_screen.dart';
import '../errors/app_error_handler.dart';
import 'app_error_fallback.dart';

typedef DesktopDashboardBuilder = Widget Function(
  ValueChanged<String> openModule,
);

/// The single, permanent navigation boundary for the Windows application.
///
/// Module routes are hosted in a nested navigator so detail screens remain
/// inside the desktop workspace. Android and iOS never instantiate this class.
class DesktopWorkspaceScreen extends StatefulWidget {
  const DesktopWorkspaceScreen({
    super.key,
    required this.dashboardBuilder,
    required this.onLogout,
  });

  final DesktopDashboardBuilder dashboardBuilder;
  final VoidCallback onLogout;

  @override
  State<DesktopWorkspaceScreen> createState() =>
      _DesktopWorkspaceScreenState();
}

class _DesktopWorkspaceScreenState extends State<DesktopWorkspaceScreen> {
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();

  String _selected = 'Dashboard';
  bool _collapsed = false;
  bool _navigationLocked = false;

  static const _navy = Color(0xFF09213C);
  static const _teal = Color(0xFF0F766E);

  static const _items = <_DesktopNavItem>[
    _DesktopNavItem('Dashboard', Icons.dashboard_rounded),
    _DesktopNavItem('Today Queue', Icons.groups_rounded),
    _DesktopNavItem('Patients', Icons.people_alt_rounded),
    _DesktopNavItem('Prescriptions', Icons.receipt_long_rounded),
    _DesktopNavItem('Prescription History', Icons.history_rounded),
    _DesktopNavItem('Patient History', Icons.manage_search_rounded),
    _DesktopNavItem('Medicines', Icons.medication_rounded),
    _DesktopNavItem('Stock', Icons.inventory_2_rounded),
    _DesktopNavItem('Billing', Icons.account_balance_wallet_rounded),
    _DesktopNavItem('Follow-ups', Icons.event_available_rounded),
    _DesktopNavItem('Laboratories', Icons.science_rounded),
    _DesktopNavItem('Lab Reports', Icons.assignment_turned_in_rounded),
    _DesktopNavItem('Analytics', Icons.bar_chart_rounded),
    _DesktopNavItem('Reception Accounts', Icons.support_agent_rounded),
    _DesktopNavItem('Doctor Profile', Icons.account_circle_rounded),
  ];

  void _openLegacyModule(String title) {
    const aliases = <String, String>{
      'Create Prescription': 'Prescriptions',
      'Patient Master': 'Patients',
      'Medicine Stock': 'Stock',
      'Income Report': 'Billing',
      'Follow-Ups': 'Follow-ups',
    };
    _openModule(aliases[title] ?? title);
  }

  void _openModule(String module) {
    if (_navigationLocked) return;
    if (!_items.any((item) => item.title == module)) return;

    _navigationLocked = true;
    try {
      final navigator = _contentNavigatorKey.currentState;
      if (navigator == null) return;

      setState(() => _selected = module);
      navigator.pushReplacement(
        PageRouteBuilder<void>(
          settings: RouteSettings(name: 'desktop/$module'),
          pageBuilder: (_, __, ___) => _safeBuildModule(module),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 160),
        ),
      );
    } catch (error, stackTrace) {
      AppErrorHandler.recordUnawaited(
        error,
        stackTrace,
        source: 'DesktopNavigation',
        context: module,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This section could not be opened. Please retry.'),
          ),
        );
      }
    } finally {
      _navigationLocked = false;
    }
  }

  Widget _safeBuildModule(String module) {
    try {
      switch (module) {
        case 'Dashboard':
          return widget.dashboardBuilder(_openLegacyModule);
        case 'Today Queue':
          return const DoctorQueueScreen(embeddedDesktop: true);
        case 'Patients':
          return const PatientMasterScreen(embeddedDesktop: true);
        case 'Prescriptions':
          return const PrescriptionListScreen();
        case 'Prescription History':
          return const PrescriptionHistoryScreen();
        case 'Patient History':
          return const PatientHistoryScreen();
        case 'Medicines':
          return const MedicineScreen();
        case 'Stock':
          return const MedicineStockScreen();
        case 'Billing':
          return const BillingReportScreen();
        case 'Follow-ups':
          return const FollowUpScreen();
        case 'Laboratories':
          return const LaboratoryListScreen();
        case 'Lab Reports':
          return const PatientLabReportsScreen();
        case 'Analytics':
          return const DashboardAnalyticsScreen();
        case 'Reception Accounts':
          return const ManageReceptionAccountsScreen();
        case 'Doctor Profile':
          return const DoctorProfileScreen();
        default:
          return const _DesktopUnknownModule();
      }
    } catch (error, stackTrace) {
      AppErrorHandler.recordUnawaited(
        error,
        stackTrace,
        source: 'DesktopModuleBuild',
        context: module,
      );
      return const AppErrorFallback();
    }
  }

  Route<void> _initialRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'desktop/Dashboard'),
      builder: (_) => _safeBuildModule('Dashboard'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F7),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: _collapsed ? 76 : 244,
            color: _navy,
            child: SafeArea(
              child: Column(
                children: [
                  _brand(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _items.length,
                      itemBuilder: (_, index) => _navItem(_items[index]),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Navigator(
              key: _contentNavigatorKey,
              restorationScopeId: 'desktop_content_navigator',
              onGenerateRoute: _initialRoute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_collapsed ? 10 : 18, 18, 10, 18),
      child: Row(
        mainAxisAlignment:
            _collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital_rounded,
              color: Colors.white, size: 29),
          if (!_collapsed) ...[
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'PRIVATE\nPRACTICES',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Collapse sidebar',
              onPressed: () => setState(() => _collapsed = true),
              color: const Color(0xFFB8C7D7),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ] else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _navItem(_DesktopNavItem item) {
    final selected = item.title == _selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: _collapsed ? item.title : '',
        child: Material(
          color: selected ? _teal : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: () => _openModule(item.title),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? 0 : 13,
                vertical: 11,
              ),
              child: Row(
                mainAxisAlignment: _collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    item.icon,
                    color: selected
                        ? Colors.white
                        : const Color(0xFFB8C7D7),
                    size: 20,
                  ),
                  if (!_collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFD8E2EC),
                          fontSize: 12.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: [
            IconButton(
              tooltip: 'Expand sidebar',
              onPressed: () => setState(() => _collapsed = false),
              color: const Color(0xFFB8C7D7),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: 'Secure logout',
              onPressed: widget.onLogout,
              color: const Color(0xFFB8C7D7),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: Color(0xFF75D9C2), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Secure clinical workspace',
                    style: TextStyle(
                        color: Color(0xFF9FB2C5), fontSize: 10.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.onLogout,
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD8E2EC)),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Secure Logout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavItem {
  const _DesktopNavItem(this.title, this.icon);

  final String title;
  final IconData icon;
}

class _DesktopUnknownModule extends StatelessWidget {
  const _DesktopUnknownModule();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF3F7F7),
      child: Center(child: Text('This desktop module is not available.')),
    );
  }
}
