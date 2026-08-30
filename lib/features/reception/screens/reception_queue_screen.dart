import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/offline_fallback_policy.dart';
import '../../../core/widgets/app_error_ui.dart';
import '../../patient/data/api_patient_service.dart';
import '../../queue/services/queue_local_page_service.dart';
import '../../queue/services/queue_realtime_service.dart';
import '../../queue/services/queue_sync_service.dart';

class ReceptionQueueScreen extends StatefulWidget {
  final String initialTab;

  const ReceptionQueueScreen({
    super.key,
    this.initialTab = 'waiting',
  });

  @override
  State<ReceptionQueueScreen> createState() => _ReceptionQueueScreenState();
}

class _ReceptionQueueScreenState extends State<ReceptionQueueScreen>
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
  String _error = '';
  String _selectedTab = 'waiting';

  List<dynamic> _patients = [];
  List<dynamic> _previousPendingPatients = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _queueEventSubscription =
        QueueRealtimeService.instance.events.listen(_onQueueChanged);
    _scrollController.addListener(_onScroll);

    _selectedTab = widget.initialTab;
    unawaited(_loadData(showLoader: true));
    unawaited(QueueRealtimeService.instance.connect());
  }

  void _onQueueChanged(Map<String, dynamic> event) {
    if (!mounted) return;

    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        if (!mounted) return;
        unawaited(_loadData(performSync: false));
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
    unawaited(_loadData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _realtimeRefreshDebounce?.cancel();
    unawaited(_queueEventSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadData({
    bool showLoader = false,
    bool performSync = true,
  }) async {
    if (_refreshing) {
      _refreshRequested = true;
      return;
    }

    _refreshing = true;

    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    Object? syncError;
    if (performSync) {
      try {
        await QueueSyncService.instance.syncChanges();
      } catch (error) {
        syncError = error;
      }
    }

    try {
      final today = await _localPages.getToday(
        status: _selectedTab == 'completed'
            ? 'Completed'
            : _selectedTab == 'skipped'
                ? 'Skipped'
                : 'waiting',
        page: 1,
      );
      final previous = _selectedTab == 'waiting'
          ? await _localPages.getPreviousPending(page: 1)
          : const QueueLocalPage(items: [], hasMore: false);

      if (!mounted) return;
      setState(() {
        _patients = today.items;
        _previousPendingPatients = previous.items;
        _todayPage = 1;
        _previousPage = 1;
        _hasMoreToday = today.hasMore;
        _hasMorePrevious = previous.hasMore;
        _loading = false;
        _error = syncError != null &&
                _patients.isEmpty &&
                _previousPendingPatients.isEmpty &&
                !OfflineFallbackPolicy.isAllowed(syncError)
            ? AppErrorUiModel.fromError(syncError).message
            : '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorUiModel.fromError(error).message;
        _loading = false;
      });
    } finally {
      _refreshing = false;
      if (_refreshRequested && mounted) {
        _refreshRequested = false;
        unawaited(_loadData());
      }
    }
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

  int? _patientId(Map<String, dynamic> patient) {
    final value = patient['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _moveToToday(Map<String, dynamic> patient) async {
    final id = _patientId(patient);

    if (id == null) {
      _showMessage('Patient ID not found', isError: true);
      return;
    }

    try {
      await _api.movePatientToToday(id);

      if (!mounted) return;
      _showMessage('Patient moved to today queue');
      await _loadData(showLoader: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Move failed: $e', isError: true);
    }
  }

  Future<void> _completePatient(Map<String, dynamic> patient) async {
    final id = _patientId(patient);

    if (id == null) {
      _showMessage('Patient ID not found', isError: true);
      return;
    }

    try {
      await _api.completePatient(id);

      if (!mounted) return;
      _showMessage('Patient completed');
      await _loadData(showLoader: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Complete failed: $e', isError: true);
    }
  }

  Future<void> _removePatient(Map<String, dynamic> patient) async {
    final id = _patientId(patient);

    if (id == null) {
      _showMessage('Patient ID not found', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove from Queue'),
          content: Text(
            'Remove ${patient['patientName'] ?? 'this patient'} '
            'from the pending queue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _api.skipPatient(id);

      if (!mounted) return;
      _showMessage('Patient removed from queue');
      await _loadData(showLoader: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Remove failed: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _patientCard(
    Map<String, dynamic> patient, {
    bool isPreviousPending = false,
  }) {
    final queueNo = patient['queueNo']?.toString() ?? '-';
    final code = patient['patientCode']?.toString() ?? '-';
    final name = patient['patientName']?.toString() ?? '';
    final age = patient['patientAge']?.toString() ?? '';
    final gender = patient['patientGender']?.toString() ?? '';
    final phone = patient['phoneNumber']?.toString() ?? '';
    final status = patient['queueStatus']?.toString() ?? '';
    final queueDate = patient['queueDate']?.toString() ?? '';

    final isServing = status == 'Serving';
    final isCompleted = status == 'Completed';
    final isSkipped = status == 'Skipped';

    final statusColor = isServing
        ? Colors.green
        : isCompleted
            ? Colors.blue
            : isSkipped
                ? Colors.orange
                : Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPreviousPending
              ? Colors.deepOrange.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      color: isPreviousPending
          ? Colors.orange.shade50
          : isServing
              ? Colors.green.shade50
              : isCompleted
                  ? Colors.blue.shade50
                  : isSkipped
                      ? Colors.orange.shade50
                      : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPreviousPending
                      ? Colors.deepOrange
                      : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  child: Text(queueNo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unnamed Patient' : name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: $code  •  $age / $gender',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  backgroundColor: statusColor,
                  label: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Phone: $phone'),
            ],
            if (queueDate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Queue Date: ${queueDate.split('T').first}',
                style: TextStyle(
                  color: isPreviousPending
                      ? Colors.deepOrange.shade700
                      : Colors.black54,
                  fontWeight:
                      isPreviousPending ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
            if (isPreviousPending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _moveToToday(patient),
                    icon: const Icon(Icons.today),
                    label: const Text('Move to Today'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _completePatient(patient),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Complete'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _removePatient(patient),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _loadData(showLoader: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final completelyEmpty = _patients.isEmpty &&
        (_selectedTab != 'waiting' || _previousPendingPatients.isEmpty);

    if (completelyEmpty) {
      return Center(child: Text('No $_selectedTab patients for today'));
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoader: false),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedTab == 'waiting') ...[
            _sectionHeader(
              title: "Today's Patients",
              count: _patients.length,
              icon: Icons.today,
              color: Colors.blue,
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
            _sectionHeader(
              title: 'Previous Pending',
              count: _previousPendingPatients.length,
              icon: Icons.warning_amber_rounded,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Reception Queue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(showLoader: true),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'waiting',
                  label: Text('Waiting'),
                  icon: Icon(Icons.queue),
                ),
                ButtonSegment(
                  value: 'skipped',
                  label: Text('Skipped'),
                  icon: Icon(Icons.skip_next),
                ),
                ButtonSegment(
                  value: 'completed',
                  label: Text('Done'),
                  icon: Icon(Icons.check_circle_outline),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (value) {
                setState(() {
                  _selectedTab = value.first;
                  _patients = [];
                  _previousPendingPatients = [];
                });

                _loadData(showLoader: true);
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
