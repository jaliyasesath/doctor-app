import 'package:flutter/material.dart';

/// Windows-only presentation layer for the doctor dashboard.
///
/// All data and actions are supplied by [HomeScreen], so the desktop surface
/// reuses the existing API, offline database, sync and navigation flows.
class DesktopHomeScreen extends StatelessWidget {
  const DesktopHomeScreen({
    super.key,
    required this.doctorName,
    required this.formattedToday,
    required this.connectionOnline,
    required this.planName,
    required this.daysRemaining,
    required this.pendingSyncCount,
    required this.queueSummary,
    required this.todayIncome,
    required this.todayFollowUpCount,
    required this.unreviewedLabReportCount,
    required this.recentPrescriptions,
    required this.profilePhotoUrl,
    required this.isSyncing,
    required this.onNavigate,
    required this.onRefresh,
    required this.onSync,
    required this.onConnectionSettings,
    required this.onLogout,
    this.embedded = false,
  });

  final String doctorName;
  final String formattedToday;
  final bool connectionOnline;
  final String planName;
  final int daysRemaining;
  final int pendingSyncCount;
  final Map<String, dynamic> queueSummary;
  final Map<String, dynamic> todayIncome;
  final int todayFollowUpCount;
  final int unreviewedLabReportCount;
  final List<Map<String, dynamic>> recentPrescriptions;
  final String profilePhotoUrl;
  final bool isSyncing;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onRefresh;
  final VoidCallback onSync;
  final VoidCallback onConnectionSettings;
  final VoidCallback onLogout;
  final bool embedded;

  static const _navy = Color(0xFF09213C);
  static const _ink = Color(0xFF10243E);
  static const _muted = Color(0xFF64748B);
  static const _teal = Color(0xFF0F766E);
  static const _green = Color(0xFF15966B);
  static const _canvas = Color(0xFFF3F7F7);
  static const _line = Color(0xFFE1EAE8);

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '0') ?? 0;
  double _asDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _topBar(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1540),
                  child: Column(
                    children: [
                      _hero(),
                      const SizedBox(height: 16),
                      _summaryCards(),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1180;
                          if (compact) {
                            return Column(
                              children: [
                                _queuePanel(),
                                const SizedBox(height: 16),
                                _rightColumn(),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: _queuePanel()),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: _rightColumn()),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (embedded) return ColoredBox(color: _canvas, child: content);

    return Scaffold(
      backgroundColor: _canvas,
      body: Row(
        children: [
          _DesktopSidebar(onNavigate: onNavigate),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 430,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search patients, prescriptions or medicines...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF7FAFA),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _line),
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Connection settings',
            onPressed: onConnectionSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFDDF3EE),
            backgroundImage:
                profilePhotoUrl.isEmpty ? null : NetworkImage(profilePhotoUrl),
            child: profilePhotoUrl.isEmpty
                ? Text(
                    doctorName.isEmpty ? 'D' : doctorName[0].toUpperCase(),
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 11),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dr. $doctorName',
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w800)),
              const Text('General Practitioner',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B665E), Color(0xFF149674), Color(0xFF35B988)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Good day,',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Dr. $doctorName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 7),
                Text(formattedToday,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _heroPill(
                      connectionOnline
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      connectionOnline ? 'Cloud Mode • Online' : 'Offline Mode',
                    ),
                    _heroPill(Icons.sync_rounded,
                        pendingSyncCount == 0 ? 'All data synced' : '$pendingSyncCount pending sync'),
                    _heroPill(Icons.verified_user_outlined,
                        '$planName • $daysRemaining days'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 190,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.health_and_safety_outlined,
                color: Colors.white, size: 74),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 7),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    final items = <({String label, int value, IconData icon, Color color})>[
      (label: 'Waiting', value: _asInt(queueSummary['waiting']), icon: Icons.groups_rounded, color: const Color(0xFFD97706)),
      (label: 'Serving', value: _asInt(queueSummary['serving']), icon: Icons.person_rounded, color: _teal),
      (label: 'Completed', value: _asInt(queueSummary['completed']), icon: Icons.check_circle_rounded, color: const Color(0xFF2563A8)),
      (label: 'Skipped', value: _asInt(queueSummary['skipped']), icon: Icons.cancel_rounded, color: const Color(0xFFD34F5F)),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _DesktopCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: items[i].color.withValues(alpha: .11),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(items[i].icon, color: items[i].color),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${items[i].value}',
                          style: const TextStyle(
                              color: _ink, fontSize: 25, fontWeight: FontWeight.w900)),
                      Text(items[i].label,
                          style: const TextStyle(color: _muted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _queuePanel() {
    return _DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: _teal),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Queue",
                          style: TextStyle(
                              color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text("View and manage today's patients",
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => onNavigate('Today Queue'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('View Queue'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          SizedBox(
            height: 285,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                        color: Color(0xFFEEF5F4), shape: BoxShape.circle),
                    child: const Icon(Icons.groups_2_outlined,
                        color: Color(0xFF9CB0AD), size: 42),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _asInt(queueSummary['waiting']) == 0
                        ? 'No patients waiting'
                        : '${_asInt(queueSummary['waiting'])} patient(s) waiting',
                    style: const TextStyle(
                        color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text('Open the queue to manage consultations.',
                      style: TextStyle(color: _muted)),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onNavigate('Patient Master'),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Patients'),
                      ),
                      FilledButton.icon(
                        onPressed: () => onNavigate('Create Prescription'),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Create Prescription'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightColumn() {
    return Column(
      children: [
        _DesktopCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Actions',
                  style: TextStyle(
                      color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.65,
                children: [
                  _quickAction('Prescription', Icons.note_add_outlined, _teal,
                      () => onNavigate('Create Prescription')),
                  _quickAction('Patients', Icons.people_alt_outlined,
                      const Color(0xFF2563A8), () => onNavigate('Patient Master')),
                  _quickAction('Medicines', Icons.medication_outlined,
                      const Color(0xFF6D55C5), () => onNavigate('Medicines')),
                  _quickAction('Stock', Icons.inventory_2_outlined,
                      const Color(0xFFC87917), () => onNavigate('Medicine Stock')),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  icon: isSyncing
                      ? const SizedBox.square(
                          dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DesktopCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Clinic Overview',
                  style: TextStyle(
                      color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _overviewRow(Icons.account_balance_wallet_outlined, 'Today income',
                  'Rs. ${_asDouble(todayIncome['total_income']).toStringAsFixed(2)}'),
              _overviewRow(Icons.notification_important_outlined, 'Follow-ups',
                  '$todayFollowUpCount due'),
              _overviewRow(Icons.science_outlined, 'Lab reports',
                  '$unreviewedLabReportCount awaiting'),
              _overviewRow(Icons.history_rounded, 'Recent prescriptions',
                  '${recentPrescriptions.length} records', last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAction(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewRow(IconData icon, String label, String value,
      {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _teal, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: _muted))),
          Text(value,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final items = <({String title, String route, IconData icon})>[
      (title: 'Dashboard', route: '', icon: Icons.dashboard_rounded),
      (title: 'Today Queue', route: 'Today Queue', icon: Icons.groups_rounded),
      (title: 'Patients', route: 'Patient Master', icon: Icons.people_alt_rounded),
      (title: 'Prescriptions', route: 'Create Prescription', icon: Icons.receipt_long_rounded),
      (title: 'Medicines', route: 'Medicines', icon: Icons.medication_rounded),
      (title: 'Stock', route: 'Medicine Stock', icon: Icons.inventory_2_rounded),
      (title: 'Billing', route: 'Income Report', icon: Icons.account_balance_wallet_rounded),
      (title: 'Follow-ups', route: 'Follow-Ups', icon: Icons.event_available_rounded),
      (title: 'Laboratories', route: 'Laboratories', icon: Icons.science_rounded),
      (title: 'Analytics', route: 'Analytics', icon: Icons.bar_chart_rounded),
    ];
    return Container(
      width: 244,
      color: DesktopHomeScreen._navy,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 18, 23),
              child: Row(
                children: [
                  Icon(Icons.local_hospital_rounded, color: Colors.white, size: 31),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('PRIVATE\nPRACTICES',
                        style: TextStyle(
                            color: Colors.white,
                            height: 1.15,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == 0;
                  return Material(
                    color: selected ? DesktopHomeScreen._teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      onTap: item.route.isEmpty ? null : () => onNavigate(item.route),
                      borderRadius: BorderRadius.circular(11),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            Icon(item.icon,
                                color: selected ? Colors.white : const Color(0xFFB8C7D7),
                                size: 21),
                            const SizedBox(width: 13),
                            Text(item.title,
                                style: TextStyle(
                                  color: selected ? Colors.white : const Color(0xFFD8E2EC),
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF75D9C2), size: 18),
                  SizedBox(width: 8),
                  Text('Secure clinical workspace',
                      style: TextStyle(color: Color(0xFF9FB2C5), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopCard extends StatelessWidget {
  const _DesktopCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesktopHomeScreen._line),
        boxShadow: [
          BoxShadow(
            color: DesktopHomeScreen._navy.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}
