import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/offline_fallback_policy.dart';
import '../../../core/widgets/app_error_ui.dart';
import '../../patient/data/api_patient_service.dart';
import '../../prescription/screens/prescription_list_screen.dart';
import '../services/queue_local_page_service.dart';
import '../services/queue_realtime_service.dart';
import '../services/queue_sync_service.dart';

class DoctorQueueScreen extends StatefulWidget {
  const DoctorQueueScreen({super.key});

  @override
  State<DoctorQueueScreen> createState() => _DoctorQueueScreenState();
}

class _DoctorQueueScreenState extends State<DoctorQueueScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _queueEventSubscription;
  Timer? _realtimeRefreshDebounce;
  final ScrollController _scrollController = ScrollController();

  final ApiPatientService _api = ApiPatientService();
  final QueueLocalPageService _localPages = QueueLocalPageService();

  bool _loading = true;
  bool _refreshing = false;
  bool _refreshRequested = false;
  bool _loadingMore = false;
  bool _hasMoreToday = false;
  bool _hasMorePrevious = false;
  int _todayPage = 1;
  int _previousPage = 1;
  String _selectedTab = 'waiting';
  String _error = '';

  List<dynamic> _patients = [];
  List<dynamic> _previousPendingPatients = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _queueEventSubscription =
        QueueRealtimeService.instance.events.listen(_onQueueChanged);
    _scrollController.addListener(_onScroll);

    unawaited(_reloadCurrentTab(silent: false));
    unawaited(QueueRealtimeService.instance.connect());
  }

  void _onQueueChanged(Map<String, dynamic> event) {
    if (!mounted) return;

    // Several changes can be committed close together. One short debounce
    // converts those events into a single consistent queue refresh.
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        if (!mounted) return;
        unawaited(_reloadCurrentTab(silent: true, performSync: false));
      },
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      unawaited(_loadMore());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(QueueRealtimeService.instance.connect());
    unawaited(_reloadCurrentTab(silent: true));
  }

  Future<void> _reloadCurrentTab({
    bool silent = false,
    bool performSync = true,
  }) async {
    if (_refreshing) {
      _refreshRequested = true;
      return;
    }

    _refreshing = true;

    try {
      if (_selectedTab == 'completed') {
        await _loadCompleted(
          silent: silent,
          performSync: performSync,
        );
      } else if (_selectedTab == 'skipped') {
        await _loadSkipped(
          silent: silent,
          performSync: performSync,
        );
      } else {
        await _loadWaiting(
          silent: silent,
          performSync: performSync,
        );
      }
    } finally {
      _refreshing = false;
      if (_refreshRequested && mounted) {
        _refreshRequested = false;
        unawaited(_reloadCurrentTab(silent: true));
      }
    }
  }

  void _startLoading(String tab, {required bool silent}) {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _patients = [];
        if (tab == 'waiting') {
          _previousPendingPatients = [];
        }
        _selectedTab = tab;
        _error = '';
      });
    } else {
      setState(() {
        _selectedTab = tab;
        _error = '';
      });
    }
  }

  Future<void> _loadWaiting({
    bool silent = false,
    bool performSync = true,
  }) async {
    _startLoading('waiting', silent: silent);
    final syncError = performSync ? await _syncQueueBestEffort() : null;

    try {
      final today = await _localPages.getToday(
        status: 'waiting',
        page: 1,
      );
      final previous = await _localPages.getPreviousPending(page: 1);

      if (!mounted) return;
      setState(() {
        _patients = today.items;
        _previousPendingPatients = previous.items;
        _todayPage = 1;
        _previousPage = 1;
        _hasMoreToday = today.hasMore;
        _hasMorePrevious = previous.hasMore;
        _loading = false;
        _error = _visibleSyncError(syncError,
            hasLocalData:
                _patients.isNotEmpty || _previousPendingPatients.isNotEmpty);
      });
    } catch (error) {
      _showLoadError(error);
    }
  }

  Future<void> _loadCompleted({
    bool silent = false,
    bool performSync = true,
  }) async {
    _startLoading('completed', silent: silent);
    final syncError = performSync ? await _syncQueueBestEffort() : null;

    try {
      final page = await _localPages.getToday(
        status: 'Completed',
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _patients = page.items;
        _previousPendingPatients = [];
        _todayPage = 1;
        _hasMoreToday = page.hasMore;
        _hasMorePrevious = false;
        _loading = false;
        _error = _visibleSyncError(
          syncError,
          hasLocalData: _patients.isNotEmpty,
        );
      });
    } catch (error) {
      _showLoadError(error);
    }
  }

  Future<void> _loadSkipped({
    bool silent = false,
    bool performSync = true,
  }) async {
    _startLoading('skipped', silent: silent);
    final syncError = performSync ? await _syncQueueBestEffort() : null;

    try {
      final page = await _localPages.getToday(
        status: 'Skipped',
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _patients = page.items;
        _previousPendingPatients = [];
        _todayPage = 1;
        _hasMoreToday = page.hasMore;
        _hasMorePrevious = false;
        _loading = false;
        _error = _visibleSyncError(
          syncError,
          hasLocalData: _patients.isNotEmpty,
        );
      });
    } catch (error) {
      _showLoadError(error);
    }
  }

  Future<Object?> _syncQueueBestEffort() async {
    try {
      await QueueSyncService.instance.syncChanges();
      return null;
    } catch (error) {
      return error;
    }
  }

  String _visibleSyncError(
    Object? error, {
    required bool hasLocalData,
  }) {
    if (error == null ||
        hasLocalData ||
        OfflineFallbackPolicy.isAllowed(error)) {
      return '';
    }
    return AppErrorUiModel.fromError(error).message;
  }

  void _showLoadError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = AppErrorUiModel.fromError(error).message;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;

    final canLoadToday = _hasMoreToday;
    final canLoadPrevious = _selectedTab == 'waiting' && _hasMorePrevious;
    if (!canLoadToday && !canLoadPrevious) return;

    setState(() => _loadingMore = true);
    try {
      if (canLoadToday) {
        final nextPage = _todayPage + 1;
        final page = await _localPages.getToday(
          status: _selectedTab == 'completed'
              ? 'Completed'
              : _selectedTab == 'skipped'
                  ? 'Skipped'
                  : 'waiting',
          page: nextPage,
        );
        if (!mounted) return;
        setState(() {
          _patients = _mergeById(_patients, page.items);
          _todayPage = nextPage;
          _hasMoreToday = page.hasMore;
        });
      } else if (canLoadPrevious) {
        final nextPage = _previousPage + 1;
        final page = await _localPages.getPreviousPending(page: nextPage);
        if (!mounted) return;
        setState(() {
          _previousPendingPatients =
              _mergeById(_previousPendingPatients, page.items);
          _previousPage = nextPage;
          _hasMorePrevious = page.hasMore;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<dynamic> _mergeById(
    List<dynamic> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    final byId = <String, dynamic>{};
    for (final item in [...existing, ...incoming]) {
      final map = Map<String, dynamic>.from(item as Map);
      byId[map['id']?.toString() ?? 'local:${map['localId']}'] = map;
    }
    return byId.values.toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _realtimeRefreshDebounce?.cancel();
    unawaited(_queueEventSubscription?.cancel());
    super.dispose();
  }

  Future<void> _skipPatient(int id) async {
    try {
      await _api.skipPatient(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient skipped')),
      );

      await _loadWaiting(silent: false);
    } catch (e) {
      if (!mounted) return;

      AppErrorUi.show(
        context,
        e,
        onRetry: () => _skipPatient(id),
      );
    }
  }

  Future<void> _movePatientToToday(int id) async {
    try {
      await _api.movePatientToToday(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient moved to today queue'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadWaiting(silent: false);
    } catch (e) {
      if (!mounted) return;
      AppErrorUi.show(
        context,
        e,
        onRetry: () => _movePatientToToday(id),
      );
    }
  }

  Future<void> _completePatient(int id) async {
    try {
      await _api.completePatient(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient completed')),
      );

      await _reloadCurrentTab(silent: false);
    } catch (e) {
      if (!mounted) return;
      AppErrorUi.show(
        context,
        e,
        onRetry: () => _completePatient(id),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'serving':
        return const Color(0xFF0F766E);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'skipped':
        return const Color(0xFFDC2626);
      case 'waiting':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _statusCardColor(String status) {
    switch (status.toLowerCase()) {
      case 'serving':
        return const Color(0xFFECFDF5);
      case 'completed':
        return const Color(0xFFF0FDF4);
      case 'skipped':
        return const Color(0xFFFEF2F2);
      case 'waiting':
      default:
        return Colors.white;
    }
  }

  Widget _patientCard(
    Map<String, dynamic> p, {
    bool isPreviousPending = false,
  }) {
    final id = p['id'] as int;
    final code = p['patientCode']?.toString() ?? '-';
    final queueNo = p['queueNo']?.toString() ?? '-';
    final name = p['patientName']?.toString() ?? '';
    final age = p['patientAge']?.toString() ?? '';
    final gender = p['patientGender']?.toString() ?? '';
    final phone = p['phoneNumber']?.toString() ?? '';
    final status = p['queueStatus']?.toString() ?? '';
    final queueDate = p['queueDate']?.toString() ?? '';

    final isCompleted = status == 'Completed';
    final isSkipped = status == 'Skipped';

    final statusColor = _statusColor(status);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPreviousPending
              ? const Color(0xFFFED7AA)
              : statusColor.withOpacity(0.16),
        ),
      ),
      color: isPreviousPending
          ? const Color(0xFFFFFBEB)
          : _statusCardColor(status),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: statusColor,
                  child: Text(
                    queueNo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unnamed Patient' : name,
                        style: const TextStyle(
                          color: Color(0xFF14213D),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Patient ID: $code',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  side: BorderSide.none,
                  backgroundColor: statusColor,
                  label: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _detailItem(Icons.cake_outlined, '$age years'),
                  _detailItem(Icons.person_outline, gender),
                  if (phone.isNotEmpty)
                    _detailItem(Icons.phone_outlined, phone),
                ],
              ),
            ),
            if (queueDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: isPreviousPending
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF718096),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Queue Date: ${queueDate.split('T').first}',
                      style: TextStyle(
                        color: isPreviousPending
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF718096),
                        fontSize: 12,
                        fontWeight: isPreviousPending
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            if (isPreviousPending)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _movePatientToToday(id),
                      icon: const Icon(Icons.today),
                      label: const Text('Move to Today'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _completePatient(id),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete'),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _skipPatient(id),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remove'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!isCompleted && !isSkipped) {
                          try {
                            await _api.setServingPatient(id);
                          } catch (_) {}
                        }

                        if (!mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrescriptionListScreen(
                              patientName: name,
                              patientAge: age,
                              patientGender: gender,
                              patientPhone: phone,
                              patientAddress: p['address']?.toString() ?? '',
                              existingPatientId: id,
                            ),
                          ),
                        );

                        await _reloadCurrentTab(silent: false);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(isCompleted ? 'View' : 'Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_selectedTab == 'waiting') ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _skipPatient(id),
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Skip'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(
                                color: Color(0xFFFCA5A5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _completePatient(id),
                            icon: const Icon(Icons.check),
                            label: const Text('Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0F766E)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_patients.isEmpty &&
        (_selectedTab != 'waiting' || _previousPendingPatients.isEmpty)) {
      return Center(
        child: Text(
          _selectedTab == 'completed'
              ? 'No completed patients'
              : _selectedTab == 'skipped'
                  ? 'No skipped patients'
                  : 'No waiting patients',
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: () => _reloadCurrentTab(silent: false),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedTab == 'waiting') ...[
            _queueSectionHeader(
              icon: Icons.today,
              title: "Today's Patients",
              count: _patients.length,
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 10),
          ],
          if (_patients.isEmpty && _selectedTab == 'waiting')
            _emptySection('No patients in today queue')
          else
            ..._patients.map((item) {
              final patient = Map<String, dynamic>.from(item as Map);
              return _patientCard(patient);
            }),
          if (_selectedTab == 'waiting' &&
              _previousPendingPatients.isNotEmpty) ...[
            const SizedBox(height: 20),
            _queueSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Previous Pending',
              count: _previousPendingPatients.length,
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 5),
            const Text(
              'Patients still waiting from earlier dates',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ..._previousPendingPatients.map((item) {
              final patient = Map<String, dynamic>.from(item as Map);
              return _patientCard(
                patient,
                isPreviousPending: true,
              );
            }),
          ],
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _queueSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF14213D),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedTab == 'completed'
        ? 'Completed Patients'
        : _selectedTab == 'skipped'
            ? 'Skipped Patients'
            : 'Today Queue';

    final greenScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Theme.of(context).brightness,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: greenScheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7F6),
        appBar: AppBar(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF075E54),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF075E54),
                  Color(0xFF0F766E),
                  Color(0xFF22A06B),
                ],
              ),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => _reloadCurrentTab(silent: false),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCE9E5)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'waiting',
                    label: Text('Waiting'),
                    icon: Icon(Icons.queue),
                  ),
                  ButtonSegment(
                    value: 'completed',
                    label: Text('Completed'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: 'skipped',
                    label: Text('Skipped'),
                    icon: Icon(Icons.skip_next),
                  ),
                ],
                selected: {_selectedTab},
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  side: WidgetStateProperty.all(BorderSide.none),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
                onSelectionChanged: (value) {
                  final selected = value.first;

                  if (selected == 'completed') {
                    _loadCompleted(silent: false);
                  } else if (selected == 'skipped') {
                    _loadSkipped(silent: false);
                  } else {
                    _loadWaiting(silent: false);
                  }
                },
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }
}
