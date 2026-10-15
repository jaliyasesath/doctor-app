import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pp_client_config.dart';
import 'pp_client_session.dart';
import 'pp_client_queue_screens.dart';
import 'pp_client_theme.dart';

const _green = Color(0xFF2563EB);

class PPClientApp extends StatefulWidget {
  const PPClientApp({super.key});
  @override
  State<PPClientApp> createState() => _PPClientAppState();
}

class _PPClientAppState extends State<PPClientApp> {
  late final PPClientThemeClock _clock;
  @override
  void initState() {
    super.initState();
    _clock = PPClientThemeClock();
  }
  @override
  void dispose() { _clock.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => MaterialApp(
      title: 'PP Client', debugShowCheckedModeBanner: false,
      theme: PPClientTheme.build(Brightness.light),
      darkTheme: PPClientTheme.build(Brightness.dark),
      themeMode: _clock.mode,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: PPClientTheme.isDark(context)
            ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _IdentityScreen(),
    ),
  );
}

class _IdentityScreen extends StatefulWidget {
  const _IdentityScreen();
  @override
  State<_IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<_IdentityScreen> {
  final _session = PPClientSession();
  int _tab = 0;
  bool _busy = true;
  String? _error;
  @override
  void initState() { super.initState(); _restore(); }
  Future<void> _restore() => _run(_session.restore, phase: 'session-restore');
  Future<void> _run(Future<void> Function() action, {String phase = 'screen-action'}) async {
    if (mounted) { setState(() { _busy = true; _error = null; }); }
    try { await action(); } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is PPClientError
              ? error.message
              : 'Unable to complete this action. '
                  '[${PPClientSession.diagnosticReference(error, phase)}]';
        });
      }
    } finally { if (mounted) setState(() { _busy = false; }); }
  }
  @override
  void dispose() { _session.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _session,
    builder: (context, _) => Scaffold(
      appBar: _session.profile == null || _tab == 0 ? null : AppBar(
        title: Text(_tab == 1 ? 'Find Doctor' : _tab == 2 ? 'My Queue' : 'Your Profile'), backgroundColor: Colors.transparent,
        actions: [IconButton(tooltip: 'Refresh profile',
          onPressed: _busy ? null : () => _run(_session.reloadProfile), icon: const Icon(Icons.refresh))],
      ),
      bottomNavigationBar: _session.profile == null ? null : NavigationBar(
        selectedIndex: _tab == 2 ? 1 : _tab == 3 ? 2 : 0,
        onDestinationSelected: _busy ? null : (value) => setState(() { _tab = const [0, 2, 3][value]; _error = null; }),
        destinations: const [NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.format_list_numbered), label: 'My Queue'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile')],
      ),
      body: _session.profile != null && _tab != 3
        ? (_tab == 2 ? PPClientMyQueue(session: _session)
            : PPClientDoctorBrowser(key: ValueKey(_tab), session: _session, homeMode: _tab == 0,
              onProfileRequired: () => setState(() { _tab = 3; }),
              onBooked: () => setState(() { _tab = 2; }),
              onFindDoctor: () => setState(() { _tab = 1; }),
              onMyQueue: () => setState(() { _tab = 2; }),
              onProfile: () => setState(() { _tab = 3; })))
        : SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_session.profile == null) ...[
              Container(padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(colors: [_green, Color(0xFF0EA5E9)])),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: Image.asset('assets/images/app_icon.png', width: 52, height: 52,
                      errorBuilder: (_, __, ___) => const Icon(Icons.health_and_safety, size: 52, color: _green))),
                  const SizedBox(height: 26),
                  const Text('PP Client', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text('Your care, closer to you.', style: TextStyle(fontSize: 18, color: Colors.white)),
                ])),
              const SizedBox(height: 32),
              Text('Welcome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: PPClientTheme.ink(context))),
              const SizedBox(height: 8),
              const Text('Sign in with your Google account to access your patient profile.', style: TextStyle(fontSize: 16, height: 1.5)),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _busy ? null : () => _run(() async { await _session.signInWithGoogle(); if (mounted) setState(() { _tab = 0; }); }),
                icon: const Icon(Icons.account_circle_outlined), label: const Text('Continue with Google')),
              const SizedBox(height: 14),
              Text('Your Google password is never shared with PP Client.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: PPClientTheme.muted(context))),
            ] else ...[
              _ProfileForm(key: ValueKey(_session.profile!['patientAccountId']),
                profile: _session.profile!, busy: _busy,
                onSave: (body) => _run(() => _session.updateProfile(body))),
              const SizedBox(height: 20),
              OutlinedButton.icon(onPressed: _busy ? null : () async {
                final confirm = await showDialog<bool>(context: context,
                  builder: (context) => AlertDialog(title: const Text('Sign out?'),
                    content: const Text('Your session on this device will be ended.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out'))]));
                if (confirm == true && mounted) await _run(_session.logout);
              }, icon: const Icon(Icons.logout), label: const Text('Sign out')),
            ],
            if (_busy) ...[const SizedBox(height: 20), const Center(child: CircularProgressIndicator())],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Semantics(liveRegion: true, child: Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFFEFEA), borderRadius: BorderRadius.circular(14)),
                child: Text(_error!, style: const TextStyle(color: Color(0xFF9B3320))))),
              TextButton(onPressed: _busy ? null : _restore, child: const Text('Retry connection')),
            ],
          ],
        )),
      ))),
    ),
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.profile, required this.busy, required this.onSave});
  final Map<String, dynamic> profile;
  final bool busy;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _mobile;
  DateTime? _dob;
  String? _gender;
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile['fullName']?.toString() ?? '');
    _mobile = TextEditingController(text: widget.profile['mobileNumber']?.toString() ?? '');
    _dob = DateTime.tryParse(widget.profile['dateOfBirth']?.toString() ?? '');
    final value = widget.profile['gender']?.toString();
    _gender = _genders.contains(value) ? value : null;
  }
  @override
  void didUpdateWidget(covariant _ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.profile, oldWidget.profile)) {
      _name.text = widget.profile['fullName']?.toString() ?? '';
      _mobile.text = widget.profile['mobileNumber']?.toString() ?? '';
      _dob = DateTime.tryParse(widget.profile['dateOfBirth']?.toString() ?? '');
      final value = widget.profile['gender']?.toString();
      _gender = _genders.contains(value) ? value : null;
    }
  }
  @override
  void dispose() { _name.dispose(); _mobile.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Form(key: _form, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Your patient profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: PPClientTheme.ink(context))),
      const SizedBox(height: 8),
      Text(widget.profile['email']?.toString() ?? '', style: TextStyle(color: PPClientTheme.muted(context))),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: PPClientTheme.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: PPClientTheme.border(context))),
        child: Text(widget.profile['profileComplete'] == true
          ? 'Your profile details are saved.' : 'Complete your details before making your first booking.')),
      const SizedBox(height: 20),
      TextFormField(controller: _name, enabled: !widget.busy, maxLength: 150,
        autofillHints: const [AutofillHints.name], textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Full name'),
        validator: (value) => (value ?? '').trim().isEmpty ? 'Enter your full name.' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _mobile, enabled: !widget.busy, maxLength: 16,
        keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(labelText: 'Mobile number', hintText: '+94771234567'),
        validator: (value) => RegExp(r'^\+?[0-9]{9,15}$').hasMatch((value ?? '').trim())
          ? null : 'Enter a valid mobile number.'),
      Text('Mobile number verification is pending; saving does not verify ownership.',
        style: TextStyle(fontSize: 12, color: PPClientTheme.muted(context))),
      const SizedBox(height: 18),
      FormField<DateTime>(validator: (_) => _dob == null ? 'Select your date of birth.' : null,
        builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OutlinedButton.icon(onPressed: widget.busy ? null : () async {
            final today = DateUtils.dateOnly(DateTime.now());
            final earliest = DateTime(today.year - 130, today.month, today.day);
            final initial = _dob != null && !_dob!.isAfter(today) && !_dob!.isBefore(earliest)
              ? _dob! : DateTime(today.year - 25, today.month, today.day);
            final value = await showDatePicker(context: context, initialDate: initial,
              firstDate: earliest, lastDate: today);
            if (value != null && mounted) { setState(() { _dob = value; }); field.didChange(value); }
          }, icon: const Icon(Icons.calendar_month),
            label: Text(_dob == null ? 'Select date of birth' : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}')),
          if (field.hasError) Text(field.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ])),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(key: ValueKey(_gender), initialValue: _gender, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Gender'),
        items: _genders.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: widget.busy ? null : (value) => setState(() { _gender = value; }),
        validator: (value) => value == null ? 'Select an option.' : null),
      const SizedBox(height: 24),
      FilledButton(onPressed: widget.busy ? null : () async {
        if (!_form.currentState!.validate()) return;
        final d = _dob!;
        await widget.onSave({'fullName': _name.text.trim(), 'mobileNumber': _mobile.text.trim(),
          'dateOfBirth': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}', 'gender': _gender});
      }, child: const Text('Save profile')),
    ],
  ));
}
