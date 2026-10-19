import 'package:flutter/material.dart';
import 'package:doctor_app/core/widgets/app_error_ui.dart';
import 'package:doctor_app/features/net_service/api_client.dart';

class CentreHoursCard extends StatefulWidget {
  const CentreHoursCard({super.key});
  @override
  State<CentreHoursCard> createState() => _CentreHoursCardState();
}

class _CentreHoursCardState extends State<CentreHoursCard> {
  final _api = ApiClient();
  List<Map<String, dynamic>>? _centres;
  Object? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await _api.get('/medical-centres') as Map;
      if (mounted) {
        setState(() {
          _centres = (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule),
                title: Text(
                  'Medical Centre Hours',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('Shared opening hours for your medical centre'),
              ),
              if (_error != null)
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry loading centre hours'),
                )
              else if (_centres == null)
                const LinearProgressIndicator()
              else if (_centres!.isEmpty)
                const Text(
                    'Ask your administrator to link your medical centre.')
              else
                for (final centre in _centres!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(centre['name'].toString()),
                    subtitle: Text(
                      centre['canEdit'] == true
                          ? 'Manage shared opening hours'
                          : 'View opening hours · lead doctor manages changes',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CentreHoursScreen(centre: centre),
                        ),
                      );
                      if (mounted) await _load();
                    },
                  ),
            ],
          ),
        ),
      );
}

class CentreHoursScreen extends StatefulWidget {
  const CentreHoursScreen({super.key, required this.centre});
  final Map<String, dynamic> centre;
  @override
  State<CentreHoursScreen> createState() => _CentreHoursScreenState();
}

class _CentreHoursScreenState extends State<CentreHoursScreen> {
  final _api = ApiClient();
  late Map<String, dynamic> _centre;
  late List<Map<String, dynamic>> _week;
  late List<Map<String, dynamic>> _exceptions;
  bool _busy = false, _dirty = false;
  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  bool get _editable => _centre['canEdit'] == true;
  @override
  void initState() {
    super.initState();
    _set(widget.centre);
  }

  Map<String, dynamic> _day(Map data) => {
        'day': data['day'] ?? 0,
        'date': data['date'],
        'allDay': data['allDay'] == true,
        'slots': (data['slots'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      };
  void _set(Map<String, dynamic> centre) {
    _centre = centre;
    final schedule = centre['schedule'] as Map?;
    _week = schedule == null
        ? List.generate(7, (day) => _day({'day': day}))
        : (schedule['week'] as List).map((e) => _day(e as Map)).toList();
    _week.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
    _exceptions = (schedule?['exceptions'] as List? ?? [])
        .map((e) => _day(e as Map))
        .toList();
  }

  void _change(VoidCallback action) {
    setState(() {
      action();
      _dirty = true;
    });
  }

  Future<void> _time(Map<String, dynamic> slot, String field) async {
    final parts = slot[field].toString().split(':');
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (chosen != null && mounted) {
      _change(
        () => slot[field] =
            '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _special() async {
    if (_exceptions.length >= 60) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_exceptions.any((d) => d['date'] == key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This special date already exists.')),
      );
      return;
    }
    _change(() => _exceptions.add(_day({'date': key})));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = Map<String, dynamic>.from(
        await _api.put('/medical-centres/${_centre['id']}/hours', {
          'expectedVersion': _centre['version'],
          'schedule': {'week': _week, 'exceptions': _exceptions},
        }) as Map,
      );
      if (mounted) {
        setState(() {
          _set(result);
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared opening hours saved.')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorUi.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your opening hours have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Widget _row(Map<String, dynamic> day, {bool special = false}) {
    final slots = day['slots'] as List;
    final mode = day['allDay'] == true
        ? 'all'
        : slots.isEmpty
            ? 'closed'
            : 'sessions';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    special ? day['date'].toString() : _days[day['day'] as int],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (special && _editable)
                  IconButton(
                    tooltip: 'Remove special date',
                    onPressed: _busy
                        ? null
                        : () => _change(() => _exceptions.remove(day)),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: mode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
                DropdownMenuItem(value: 'all', child: Text('Open 24 hours')),
                DropdownMenuItem(
                  value: 'sessions',
                  child: Text('Opening sessions'),
                ),
              ],
              onChanged: !_editable || _busy
                  ? null
                  : (v) => _change(() {
                        day['allDay'] = v == 'all';
                        day['slots'] = v == 'sessions'
                            ? [
                                {'open': '09:00', 'close': '17:00'},
                              ]
                            : <Map<String, dynamic>>[];
                      }),
            ),
            if (mode == 'sessions') ...[
              for (final raw in slots)
                Builder(
                  builder: (context) {
                    final slot = raw as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: !_editable || _busy
                                ? null
                                : () => _time(slot, 'open'),
                            child: Text('Opens ${slot['open']}'),
                          ),
                          const Text('to'),
                          OutlinedButton(
                            onPressed: !_editable || _busy
                                ? null
                                : () => _time(slot, 'close'),
                            child: Text('Closes ${slot['close']}'),
                          ),
                          if (_editable)
                            IconButton(
                              tooltip: 'Remove session',
                              onPressed: _busy
                                  ? null
                                  : () => _change(() => slots.remove(slot)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              if (_editable && slots.length < 2)
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _change(
                            () =>
                                slots.add({'open': '17:00', 'close': '21:00'}),
                          ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add second session'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_dirty && !_busy,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Medical Centre Hours'),
            actions: [
              if (_editable)
                TextButton(
                  onPressed: _busy || !_dirty ? null : _save,
                  child: Text(_busy ? 'Saving…' : 'Save'),
                ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _centre['name'].toString(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Timezone: ${_centre['timeZoneId']}'),
                  const Text(
                    'These hours apply to all doctors linked to this centre. Closing earlier than opening means the session ends the next day.',
                  ),
                  if (!_editable)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Only the lead doctor or administrator can edit this schedule.',
                      ),
                    ),
                  for (final d in _week) _row(d),
                  const SizedBox(height: 16),
                  Text(
                    'Special dates & holidays',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'A special date replaces its normal weekday hours. A closed holiday also ends any previous overnight session at midnight.',
                  ),
                  for (final d in _exceptions) _row(d, special: true),
                  if (_editable)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _special,
                      icon: const Icon(Icons.event),
                      label: const Text('Add special date'),
                    ),
                  if (_editable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: FilledButton(
                        onPressed: _busy || !_dirty ? null : _save,
                        child: Text(_busy ? 'Saving…' : 'Save shared hours'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
