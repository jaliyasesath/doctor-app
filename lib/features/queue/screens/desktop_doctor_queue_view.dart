import 'package:flutter/material.dart';

import '../../../core/widgets/desktop_module_shell.dart';

class DesktopDoctorQueueView extends StatelessWidget {
  const DesktopDoctorQueueView({
    super.key,
    required this.selectedTab,
    required this.patients,
    required this.previousPendingPatients,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.scrollController,
    required this.onTabChanged,
    required this.onRefresh,
    required this.onOpen,
    required this.onSkip,
    required this.onComplete,
    required this.onMoveToToday,
    required this.onBack,
    this.embedded = false,
  });

  final String selectedTab;
  final List<dynamic> patients;
  final List<dynamic> previousPendingPatients;
  final bool loading;
  final bool loadingMore;
  final String error;
  final ScrollController scrollController;
  final ValueChanged<String> onTabChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<int> onSkip;
  final ValueChanged<int> onComplete;
  final ValueChanged<int> onMoveToToday;
  final VoidCallback onBack;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return DesktopModuleShell(
      title: 'Today Queue',
      subtitle: 'Manage waiting, completed and skipped patients',
      icon: Icons.groups_rounded,
      onBack: onBack,
      embedded: embedded,
      actions: [
        IconButton.filledTonal(
          tooltip: 'Refresh queue',
          onPressed: onRefresh,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: DesktopModuleShell.teal,
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _metric('Waiting', _waitingCount,
                    Icons.groups_rounded, const Color(0xFFD97706))),
                const SizedBox(width: 12),
                Expanded(child: _metric('Completed', _completedCount,
                    Icons.check_circle_rounded, const Color(0xFF15966B))),
                const SizedBox(width: 12),
                Expanded(child: _metric('Skipped', _skippedCount,
                    Icons.cancel_rounded, const Color(0xFFD34F5F))),
                const SizedBox(width: 12),
                Expanded(child: _metric('Previous Pending',
                    previousPendingPatients.length, Icons.history_rounded,
                    const Color(0xFF6D55C5))),
              ],
            ),
            const SizedBox(height: 16),
            DesktopPanel(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  _tab('waiting', 'Waiting', Icons.schedule_rounded),
                  _tab('completed', 'Completed', Icons.check_circle_outline),
                  _tab('skipped', 'Skipped', Icons.skip_next_rounded),
                  const Spacer(),
                  Text(
                    '${patients.length} record(s)',
                    style: const TextStyle(
                      color: DesktopModuleShell.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DesktopPanel(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error.isNotEmpty
                        ? _errorView()
                        : _queueTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _waitingCount => selectedTab == 'waiting' ? patients.length : 0;
  int get _completedCount => selectedTab == 'completed' ? patients.length : 0;
  int get _skippedCount => selectedTab == 'skipped' ? patients.length : 0;

  Widget _metric(String label, int value, IconData icon, Color color) {
    return DesktopPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: const TextStyle(
                      color: DesktopModuleShell.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w900)),
              Text(label,
                  style: const TextStyle(
                      color: DesktopModuleShell.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tab(String value, String label, IconData icon) {
    final active = selectedTab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: active
            ? DesktopModuleShell.teal
            : const Color(0xFFF3F7F7),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onTabChanged(value),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Row(
              children: [
                Icon(icon,
                    color: active
                        ? Colors.white
                        : DesktopModuleShell.muted,
                    size: 18),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : DesktopModuleShell.ink,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 54, color: Color(0xFFD34F5F)),
          const SizedBox(height: 12),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesktopModuleShell.muted)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _queueTable() {
    final rows = <({Map<String, dynamic> patient, bool previous})>[
      ...patients.map((x) =>
          (patient: Map<String, dynamic>.from(x as Map), previous: false)),
      if (selectedTab == 'waiting')
        ...previousPendingPatients.map((x) =>
            (patient: Map<String, dynamic>.from(x as Map), previous: true)),
    ];
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_2_outlined,
                size: 60, color: Color(0xFFA2B5B1)),
            const SizedBox(height: 12),
            Text(
              selectedTab == 'completed'
                  ? 'No completed patients'
                  : selectedTab == 'skipped'
                      ? 'No skipped patients'
                      : 'No waiting patients',
              style: const TextStyle(
                  color: DesktopModuleShell.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F8F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 70, child: Text('QUEUE')),
              Expanded(flex: 4, child: Text('PATIENT')),
              Expanded(flex: 2, child: Text('AGE / GENDER')),
              Expanded(flex: 2, child: Text('PHONE')),
              Expanded(flex: 2, child: Text('STATUS')),
              SizedBox(width: 220, child: Text('ACTIONS')),
            ],
          ),
        ),
        const Divider(height: 1, color: DesktopModuleShell.line),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: rows.length + (loadingMore ? 1 : 0),
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: DesktopModuleShell.line),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _row(rows[index].patient, rows[index].previous);
            },
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> p, bool previous) {
    final id = int.tryParse(p['id']?.toString() ?? '');
    final queue = p['queueNo']?.toString() ?? '-';
    final name = p['patientName']?.toString().trim().isNotEmpty == true
        ? p['patientName'].toString()
        : 'Unnamed Patient';
    final code = p['patientCode']?.toString() ?? '-';
    final age = p['patientAge']?.toString() ?? '-';
    final gender = p['patientGender']?.toString() ?? '-';
    final phone = p['phoneNumber']?.toString() ?? '-';
    final status = previous
        ? 'Previous'
        : (p['queueStatus']?.toString().trim().isNotEmpty == true
            ? p['queueStatus'].toString()
            : selectedTab);
    final statusColor = previous
        ? const Color(0xFF6D55C5)
        : status.toLowerCase() == 'completed'
            ? const Color(0xFF15966B)
            : status.toLowerCase() == 'skipped'
                ? const Color(0xFFD34F5F)
                : const Color(0xFFD97706);

    return Container(
      height: 74,
      color: previous ? const Color(0xFFFFFBEB) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: statusColor,
              child: Text(queue,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: DesktopModuleShell.ink,
                        fontWeight: FontWeight.w700)),
                Text(code,
                    style: const TextStyle(
                        color: DesktopModuleShell.muted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('$age / $gender')),
          Expanded(flex: 2, child: Text(phone)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (previous)
                  TextButton.icon(
                    onPressed: id == null ? null : () => onMoveToToday(id),
                    icon: const Icon(Icons.today_rounded, size: 17),
                    label: const Text('Move Today'),
                  )
                else
                  FilledButton.icon(
                    onPressed: id == null ? null : () => onOpen(p),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(selectedTab == 'completed' ? 'View' : 'Open'),
                  ),
                if (selectedTab == 'waiting') ...[
                  const SizedBox(width: 5),
                  IconButton(
                    tooltip: 'Skip patient',
                    onPressed: id == null ? null : () => onSkip(id),
                    color: const Color(0xFFD34F5F),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  IconButton(
                    tooltip: 'Complete patient',
                    onPressed: id == null ? null : () => onComplete(id),
                    color: const Color(0xFF15966B),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
