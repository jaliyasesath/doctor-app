import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/api_auth_service.dart';
import '../../auth/data/doctor_session.dart';
import '../../local_server/screens/reception_hotspot_connect_screen.dart';
import '../../medicines/screens/medicine_screen.dart';
import '../../patient/screens/add_patient_screen.dart' as patient_screen;
import '../../prescription/screens/prescription_history_screen.dart';
import '../../queue/services/queue_realtime_service.dart';
import '../../queue/services/queue_sync_service.dart';
import '../../stock/data/medicine_stock_api_service.dart';
import '../../stock/screens/medicine_stock_screen.dart';
import 'reception_bills_screen.dart';
import 'reception_patient_search_screen.dart';
import 'reception_queue_screen.dart';

class ReceptionDashboardScreen extends StatefulWidget {
  const ReceptionDashboardScreen({super.key});

  @override
  State<ReceptionDashboardScreen> createState() =>
      _ReceptionDashboardScreenState();
}

class _ReceptionDashboardScreenState extends State<ReceptionDashboardScreen> {
  static const _green = Color(0xFF0F766E);
  static const _deepGreen = Color(0xFF064E3B);
  static const _freshGreen = Color(0xFF22A06B);
  static const _surface = Color(0xFFF3F9F7);

  final _stockApi = MedicineStockApiService();
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _pending = [];
  String _name = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_loadPending(silent: true)),
    );
  }

  Future<void> _initialize() async {
    final doctorName = await DoctorSession.getDoctorName();
    if (mounted) setState(() => _name = doctorName);
    unawaited(QueueRealtimeService.instance.connect());
    unawaited(QueueSyncService.instance.syncChanges());
    await _loadPending();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPending({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _stockApi.allPendingPrescriptions();
      final raw = response['data'];
      final rows = raw is List
          ? raw
              .whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _pending = rows;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _pending.isEmpty) {
          _error = 'Waiting prescriptions could not be loaded.';
        }
      });
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _dispense(Map<String, dynamic> prescription) async {
    final id = int.tryParse('${prescription['id'] ?? ''}');
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid prescription. Please refresh.')),
      );
      return;
    }
    await _open(MedicineStockScreen(
      initialPrescriptionId: id,
      openDispenseOnStart: true,
    ));
    await _loadPending(silent: true);
  }

  Future<void> _logout() async {
    await QueueRealtimeService.instance.disconnect();
    await ApiAuthService().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: _green,
          onRefresh: _loadPending,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  _pendingSection(),
                  const SizedBox(height: 22),
                  _title('Today\'s Operations'),
                  const SizedBox(height: 10),
                  _grid([
                    _Action(
                        Icons.queue_rounded,
                        'Today Queue',
                        'Manage waiting patients',
                        () => _open(
                            const ReceptionQueueScreen(initialTab: 'waiting'))),
                    _Action(
                        Icons.person_add_alt_1_rounded,
                        'Register Patient',
                        'Add a new patient',
                        () => _open(const patient_screen.AddPatientScreen())),
                    _Action(
                        Icons.receipt_long_rounded,
                        'Bills',
                        'View and print receipts',
                        () => _open(const ReceptionBillsScreen())),
                  ]),
                  const SizedBox(height: 22),
                  _title('Clinical Records'),
                  const SizedBox(height: 10),
                  _grid([
                    _Action(
                        Icons.inventory_2_outlined,
                        'Medicine Stock',
                        'View stock and dispense',
                        () => _open(const MedicineStockScreen())),
                    _Action(
                        Icons.description_outlined,
                        'Prescriptions',
                        'View and print records',
                        () => _open(const PrescriptionHistoryScreen(
                            receptionMode: true))),
                    _Action(
                        Icons.medication_outlined,
                        'Medicines',
                        'View medicines and prices',
                        () => _open(const MedicineScreen())),
                    _Action(
                        Icons.search_rounded,
                        'Search Patients',
                        'Find patient records',
                        () => _open(const ReceptionPatientSearchScreen())),
                  ]),
                  const SizedBox(height: 22),
                  _title('Tools'),
                  const SizedBox(height: 10),
                  _grid([
                    _Action(
                        Icons.qr_code_scanner_rounded,
                        'Doctor Hotspot',
                        'Connect to local server',
                        () => _open(const ReceptionHotspotConnectScreen())),
                    _Action(
                        Icons.skip_next_rounded,
                        'Skipped Patients',
                        'Review skipped queue',
                        () => _open(
                            const ReceptionQueueScreen(initialTab: 'skipped'))),
                  ]),
                ])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_deepGreen, _green, _freshGreen]),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Reception Dashboard',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _loadPending,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
          IconButton(
              tooltip: 'Logout',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.white)),
        ]),
        const SizedBox(height: 16),
        Text(_name.isEmpty ? 'Welcome' : 'Welcome, $_name',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${now.day} ${months[now.month - 1]} ${now.year}',
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24)),
          child: Row(children: [
            const Icon(Icons.medication_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    '${_pending.length} prescription(s) waiting to dispense',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    );
  }

  Widget _pendingSection() {
    Widget content;
    if (_loading && _pending.isEmpty) {
      content =
          const _Status(child: Center(child: CircularProgressIndicator()));
    } else if (_error != null && _pending.isEmpty) {
      content = _Status(
          child: Column(children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center),
        TextButton(onPressed: _loadPending, child: const Text('Try Again')),
      ]));
    } else if (_pending.isEmpty) {
      content = const _Status(
          child: Row(children: [
        Icon(Icons.check_circle_rounded, color: _freshGreen),
        SizedBox(width: 10),
        Expanded(child: Text('No prescriptions are waiting.')),
      ]));
    } else {
      content = Column(children: _pending.map(_prescriptionCard).toList());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _title('Waiting to Dispense')),
        TextButton.icon(
            onPressed: () => _open(const MedicineStockScreen()),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('All stock')),
      ]),
      const SizedBox(height: 8),
      content,
    ]);
  }

  Widget _prescriptionCard(Map<String, dynamic> prescription) {
    final patient = '${prescription['patientName'] ?? ''}'.trim();
    final number = '${prescription['prescriptionNo'] ?? ''}'.trim();
    final rawItems = prescription['items'];
    final itemCount = rawItems is List ? rawItems.length : 0;
    final unmatched =
        int.tryParse('${prescription['unmatchedItemCount'] ?? 0}') ?? 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFCFE6DF))),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _dispense(prescription),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: const Color(0xFFE3F4EF),
                    borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.person_rounded, color: _green)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(patient.isEmpty ? 'Unknown patient' : patient,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      '${number.isEmpty ? 'Prescription' : number}  •  $itemCount medicine(s)',
                      style: const TextStyle(color: Colors.black54)),
                  if (unmatched > 0)
                    Text('$unmatched item(s) need medicine matching',
                        style: const TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ])),
            const Column(children: [
              Icon(Icons.medication_rounded, color: _green),
              SizedBox(height: 4),
              Text('Dispense',
                  style: TextStyle(
                      color: _green, fontSize: 11, fontWeight: FontWeight.w700))
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(text,
      style: const TextStyle(
          color: _deepGreen, fontSize: 18, fontWeight: FontWeight.w800));

  Widget _grid(List<_Action> items) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25),
        itemBuilder: (_, index) {
          final item = items[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFCFE6DF))),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: item.onTap,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: _green, size: 27),
                        const Spacer(),
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ])),
            ),
          );
        },
      );
}

class _Action {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Action(this.icon, this.title, this.subtitle, this.onTap);
}

class _Status extends StatelessWidget {
  final Widget child;
  const _Status({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCFE6DF))),
        child: child,
      );
}
