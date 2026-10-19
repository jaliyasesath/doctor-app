import 'dart:async';
import 'package:flutter/material.dart';
import 'pp_client_theme.dart';

class PPCareOpeningBadge extends StatefulWidget {
  const PPCareOpeningBadge({
    super.key,
    required this.opening,
    required this.onRefresh,
  });
  final Map<String, dynamic>? opening;
  final VoidCallback onRefresh;
  @override
  State<PPCareOpeningBadge> createState() => _PPCareOpeningBadgeState();
}

class _PPCareOpeningBadgeState extends State<PPCareOpeningBadge>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _elapsed = Stopwatch();
  bool _requested = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _elapsed.start();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  @override
  void didUpdateWidget(covariant PPCareOpeningBadge old) {
    super.didUpdateWidget(old);
    if (old.opening?['evaluatedAtUtc'] != widget.opening?['evaluatedAtUtc']) {
      _elapsed.reset();
      _requested = false;
    }
  }

  bool get _expired {
    final evaluated = DateTime.tryParse(
      widget.opening?['evaluatedAtUtc']?.toString() ?? '',
    );
    final next = DateTime.tryParse(
      widget.opening?['nextChangeUtc']?.toString() ?? '',
    );
    return _elapsed.elapsed > const Duration(minutes: 5) ||
        (evaluated != null &&
            next != null &&
            !evaluated.add(_elapsed.elapsed).isBefore(next));
  }

  void _check() {
    if (!mounted || !_foreground || widget.opening == null) return;
    if (_expired && !_requested) {
      setState(() => _requested = true);
      widget.onRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _requested = false;
      widget.onRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _expired
        ? 'unknown'
        : widget.opening?['state']?.toString() ?? 'unknown';
    final open = state == 'open';
    final closed = state == 'closed';
    final color = open
        ? (PPClientTheme.isDark(context) ? const Color(0xFF34D399) : const Color(0xFF087A4C))
        : closed
            ? (PPClientTheme.isDark(context) ? const Color(0xFFFB7185) : const Color(0xFFBE2940))
            : PPClientTheme.muted(context);
    final text = open
        ? 'Centre open now'
        : closed
            ? 'Centre closed'
            : 'Hours not provided';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Icon(
            open ? Icons.check_circle_outline : Icons.schedule,
            size: 16,
            color: color,
          ),
          Text(
            _expired ? 'Updating centre hours…' : text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (_requested)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Refresh centre hours',
              onPressed: () {
                _requested = false;
                widget.onRefresh();
              },
              icon: const Icon(Icons.refresh, size: 16),
            ),
        ],
      ),
    );
  }
}

class PPCareWeeklyHours extends StatelessWidget {
  const PPCareWeeklyHours({
    super.key,
    required this.schedule,
    required this.timezone,
  });
  final Map<String, dynamic>? schedule;
  final String timezone;
  @override
  Widget build(BuildContext context) {
    if (schedule == null) return const SizedBox.shrink();
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    String hours(Map d) => d['allDay'] == true
        ? '24 hours'
        : (d['slots'] as List).isEmpty
            ? 'Closed'
            : (d['slots'] as List)
                .map(
                  (s) =>
                      '${s['open']} – ${s['close']}${s['close'].toString().compareTo(s['open'].toString()) < 0 ? ' (+1 day)' : ''}',
                )
                .join(' / ');
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Medical centre opening hours'),
      subtitle: Text(timezone),
      children: [
        for (final raw in schedule!['week'] as List)
          ListTile(
            dense: true,
            title: Text(days[raw['day'] as int]),
            subtitle: Text(hours(raw as Map)),
          ),
        if ((schedule!['exceptions'] as List).isNotEmpty)
          const ListTile(title: Text('Special dates')),
        for (final raw in schedule!['exceptions'] as List)
          ListTile(
            dense: true,
            title: Text(raw['date'].toString()),
            subtitle: Text(hours(raw as Map)),
          ),
      ],
    );
  }
}
