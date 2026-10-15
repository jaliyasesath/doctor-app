import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pp_client_config.dart';
import 'pp_client_session.dart';
import 'pp_client_theme.dart';

String _error(Object e) => e is PPClientError ? e.message : 'Unable to load this information. Please try again.';
Color _traffic(int count, {bool dark = false}) => count <= 10
    ? (dark ? const Color(0xFF34D399) : const Color(0xFF087A4C))
    : count < 20
        ? (dark ? const Color(0xFFFBBF24) : const Color(0xFFA85B00))
        : (dark ? const Color(0xFFFB7185) : const Color(0xFFBE2940));
int _number(dynamic value) => value is num ? value.toInt() : 0;
String _requestId() {
  final random = Random.secure(); final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
}
Widget _photo(Map<String, dynamic> doctor, {double size = 58}) {
  const fallback = ColoredBox(
    color: Color(0xFFEAF3FF),
    child: Center(
      child: Icon(Icons.person_rounded, size: 40, color: Color(0xFF2563EB)),
    ),
  );
  final value = doctor['profilePhotoUrl']?.toString().trim() ?? '';
  Uri? uri;
  if (value.isNotEmpty) {
    final relative = Uri.tryParse(value);
    if (relative != null) {
      final origin = PPClientConfig.origin.toString().replaceAll(RegExp(r'/+$'), '');
      uri = Uri.parse('$origin/').resolveUri(relative);
    }
  }
  final valid = uri != null && uri.hasAuthority && uri.userInfo.isEmpty &&
      (uri.scheme == 'https' ||
          (uri.scheme == 'http' && uri.host == PPClientConfig.origin.host));
  return Semantics(
    image: true,
    label: '${doctor['doctorName'] ?? 'Doctor'} profile photo',
    child: ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: valid
            ? Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                cacheWidth: 174,
                excludeFromSemantics: true,
                frameBuilder: (_, child, frame, synchronous) =>
                    synchronous || frame != null ? child : fallback,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    ),
  );
}

Future<void> _directions(BuildContext context, Map<String, dynamic> doctor) async {
  final latitude = doctor['latitude'], longitude = doctor['longitude'];
  final destination = latitude is num && longitude is num
    ? '$latitude,$longitude' : '${doctor['medicalCenterName'] ?? ''} ${doctor['clinicAddress'] ?? ''} ${doctor['city'] ?? ''}';
  final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw const PPClientError('Unable to open Maps.');
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open Maps. Please try again.')));
  }
}

class PPClientDoctorBrowser extends StatefulWidget {
  const PPClientDoctorBrowser({super.key, required this.session, required this.onProfileRequired, required this.onBooked,
    this.homeMode = false, this.onFindDoctor, this.onMyQueue, this.onProfile});
  final PPClientSession session;
  final VoidCallback onProfileRequired, onBooked;
  final bool homeMode;
  final VoidCallback? onFindDoctor, onMyQueue, onProfile;
  @override
  State<PPClientDoctorBrowser> createState() => _DoctorBrowserState();
}
class _DoctorBrowserState extends State<PPClientDoctorBrowser> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Position? _position;
  bool _loading = false, _locating = false, _more = false;
  int _page = 1;
  String? _failure;
  String? _town;
  int _generation = 0;
  @override
  void initState() { super.initState(); _location(); }
  Future<void> _location() async {
    setState(() { if (_town != null) _search.clear(); _locating = true; _town = null; _position = null; });
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          _position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)));
        }
      }
    } catch (_) { /* Location is optional; offer city search instead of inventing distance. */ }
    if (!mounted) return;
    setState(() { _locating = false; }); await _load();
  }
  Future<void> _load({bool next = false}) async {
    if (next && _loading) return;
    final generation = ++_generation; final page = next ? _page + 1 : 1;
    setState(() { _loading = true; _failure = null; });
    try {
      final data = await widget.session.findDoctors(latitude: _position?.latitude, longitude: _position?.longitude,
        search: _search.text, page: page);
      final rows = (data['items'] as List).cast<Map<String, dynamic>>();
      if (!mounted || generation != _generation) return;
      setState(() { _items = next ? [..._items, ...rows] : rows; _page = page; _more = data['hasMore'] == true; });
    } catch (e) { if (mounted && generation == _generation) setState(() { _failure = _error(e); }); }
    finally { if (mounted && generation == _generation) setState(() { _loading = false; }); }
  }
  @override
  void dispose() { _generation++; _search.dispose(); super.dispose(); }
  Future<void> _changeLocation() async {
    final input = TextEditingController(text: _town ?? '');
    final result = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Choose your location'),
      content: TextField(controller: input, maxLength: 100,
        decoration: const InputDecoration(labelText: 'Town or city', hintText: 'Enter a town to search')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, '@gps'), child: const Text('Use GPS')),
        FilledButton(onPressed: () { if (input.text.trim().isNotEmpty) Navigator.pop(dialog, input.text.trim()); }, child: const Text('Apply'))]));
    // Wait for the dialog transition before disposing its text input controller.
    Future<void>.delayed(const Duration(milliseconds: 350), input.dispose);
    if (!mounted || result == null) return;
    if (result == '@gps') { await _location(); return; }
    setState(() { _town = result; _position = null; _search.text = result; });
    await _load();
  }

  void _service(String title, String description) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.health_and_safety_outlined, size: 64, color: Color(0xFF2563EB)),
          const SizedBox(height: 22), Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12), Text(description, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 24), OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Home')),
        ]))))));
  }

  Widget _searchField() => TextField(
    controller: _search, maxLength: 100,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _load(),
    decoration: InputDecoration(
      counterText: '', hintText: 'Search doctor, specialty or town',
      hintStyle: TextStyle(fontSize: 14, color: PPClientTheme.muted(context)),
      prefixIcon: Icon(Icons.search, color: PPClientTheme.muted(context)),
      suffixIcon: IconButton(
        tooltip: 'Search', onPressed: _loading ? null : () => _load(),
        icon: Icon(Icons.tune_rounded, color: PPClientTheme.accent(context)),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    ),
  );

  Widget _header() {
    final dark = PPClientTheme.isDark(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning!' : hour < 18
        ? 'Good afternoon!' : 'Good evening!';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF071C3D), Color(0xFF0A1424)]
              : const [Color(0xFFE5F3FF), Color(0xFFF8FCFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PPClientTheme.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: PPClientTheme.tint(context),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.health_and_safety_rounded,
                color: PPClientTheme.accent(context), size: 30),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PP Client', style: TextStyle(fontSize: 23,
                fontWeight: FontWeight.w800, color: PPClientTheme.ink(context))),
            Text('Your Health, Closer', style: TextStyle(fontSize: 12,
                color: PPClientTheme.muted(context))),
          ])),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _service('Notifications',
                'Queue alerts will be available when the notification service is connected. You can check your current status in My Queue.'),
            icon: Icon(Icons.notifications_none_rounded,
                color: PPClientTheme.accent(context)),
          ),
          IconButton.filledTonal(
            tooltip: 'Your profile', onPressed: widget.onProfile,
            style: IconButton.styleFrom(backgroundColor: PPClientTheme.tint(context)),
            icon: Icon(Icons.person_rounded, color: PPClientTheme.accent(context)),
          ),
        ]),
        const SizedBox(height: 20),
        Text(greeting, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800,
            color: PPClientTheme.ink(context))),
        const SizedBox(height: 6),
        Text('Find and book queues for doctors near you.',
            style: TextStyle(fontSize: 14, height: 1.45,
                color: PPClientTheme.muted(context))),
        const SizedBox(height: 16),
        _locationCard(),
        const SizedBox(height: 12),
        _searchField(),
      ]),
    );
  }

  Widget _locationCard() => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
    decoration: BoxDecoration(
      color: PPClientTheme.surface(context), borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PPClientTheme.border(context)),
    ),
    child: Row(children: [
      CircleAvatar(radius: 21, backgroundColor: PPClientTheme.tint(context),
          child: Icon(Icons.location_on_rounded,
              color: PPClientTheme.accent(context), size: 25)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your location', style: TextStyle(fontSize: 12,
            color: PPClientTheme.muted(context))),
        const SizedBox(height: 4),
        Text(_locating ? 'Finding your location…' : _town ??
            (_position == null ? 'Choose your location' : 'Current GPS location'),
            style: TextStyle(color: PPClientTheme.ink(context),
                fontWeight: FontWeight.w700, fontSize: 14)),
      ])),
      TextButton(
        onPressed: _locating ? null : _changeLocation,
        child: const Text('Change'),
      ),
    ]),
  );

  Widget _servicesGrid({bool closeSheet = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final columns = constraints.maxWidth >= 320 && scale < 1.4 ? 3 : 2;
      final items = <({IconData icon, String title, String subtitle, Color color, VoidCallback action})>[
        (icon: Icons.person_search_rounded, title: 'Find Doctor',
          subtitle: 'Book your queue', color: const Color(0xFF3B82F6),
          action: () => widget.onFindDoctor?.call()),
        (icon: Icons.confirmation_number_outlined, title: 'My Queue',
          subtitle: 'View your queue', color: const Color(0xFF06B6D4),
          action: () => widget.onMyQueue?.call()),
        (icon: Icons.storefront_rounded, title: 'Find Pharmacy',
          subtitle: 'Nearby pharmacies', color: const Color(0xFF6366F1),
          action: () => _service('Find Pharmacy', 'Pharmacy search is not available yet. Verified pharmacy listings will be added in the pharmacy module.')),
        (icon: Icons.science_outlined, title: 'Lab Search',
          subtitle: 'Find test centres', color: const Color(0xFF8B5CF6),
          action: () => _service('Lab Search', 'Laboratory search is not available yet. Verified laboratory listings will be added in the laboratory module.')),
        (icon: Icons.article_outlined, title: 'Medical News',
          subtitle: 'Health tips & updates', color: const Color(0xFFF59E0B),
          action: () => _service('Medical News', 'Medical news will be available when the content service is connected.')),
        (icon: Icons.folder_outlined, title: 'Health Records',
          subtitle: 'Coming soon', color: const Color(0xFF6492CB),
          action: () => _service('Health Records', 'Your health records are not available in PP Client yet. Secure record access will be added in the health records module.')),
      ];
      final tileWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
      // Measure using the actual font and accessibility scale. Fixed heights
      // can overflow when a service label wraps on a narrow phone.
      double textHeight(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: max(1.0, tileWidth - 14));
        final height = painter.height;
        painter.dispose();
        return height;
      }
      var tileHeight = tileWidth;
      for (final item in items) {
        final titleHeight = textHeight(item.title,
            const TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w800));
        final subtitleHeight = textHeight(item.subtitle,
            const TextStyle(fontSize: 11, height: 1.3));
        // Padding + avatar + gaps + measured labels + rounding headroom.
        tileHeight = max(tileHeight, (24 + 46 + 10 + titleHeight + 5 + subtitleHeight + 8).ceilToDouble());
      }
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero, itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns, crossAxisSpacing: 10,
          mainAxisSpacing: 10, mainAxisExtent: tileHeight,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final dark = PPClientTheme.isDark(context);
          return Material(
            color: Color.alphaBlend(item.color.withValues(alpha: dark ? .09 : .035),
                PPClientTheme.surface(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: item.color.withValues(alpha: dark ? .35 : .24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () { if (closeSheet) Navigator.pop(context); item.action(); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(
                    radius: 23, backgroundColor: item.color.withValues(alpha: .14),
                    child: Icon(item.icon, color: item.color, size: 27),
                  ),
                  const SizedBox(height: 10),
                  Text(item.title, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.2,
                          color: PPClientTheme.ink(context), fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(item.subtitle, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, height: 1.3,
                          color: PPClientTheme.muted(context))),
                ]),
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _openDoctor(Map<String, dynamic> doctor) async {
    final booked = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _DoctorDetails(
      session: widget.session, doctorId: _number(doctor['doctorId']), onProfileRequired: widget.onProfileRequired)));
    if (booked == true && mounted) widget.onBooked();
  }

  Widget _queueMetric(String label, String value, IconData icon, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: PPClientTheme.muted(context))),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ])),
      ]);

  Widget _doctorCard(Map<String, dynamic> doctor) {
    final waiting = _number(doctor['waitingCount']);
    final clinic = doctor['medicalCenterName']?.toString().trim() ?? '';
    final dark = PPClientTheme.isDark(context);
    final traffic = _traffic(waiting, dark: dark);
    final distance = doctor['distanceKm'];
    final distanceChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: PPClientTheme.tint(context),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on_rounded, size: 15, color: PPClientTheme.accent(context)),
        const SizedBox(width: 4),
        Text('$distance km', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: PPClientTheme.accent(context))),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: PPClientTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: PPClientTheme.border(context))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDoctor(doctor),
          child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LayoutBuilder(builder: (context, constraints) {
                final stackDistance = constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: PPClientTheme.tint(context),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.local_hospital_outlined, size: 20,
                          color: PPClientTheme.accent(context)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(clinic.isEmpty ? 'Medical centre' : clinic,
                        style: TextStyle(fontSize: 18, height: 1.25,
                            fontWeight: FontWeight.w800, color: PPClientTheme.ink(context)))),
                    if (distance != null && !stackDistance) ...[
                      const SizedBox(width: 8), distanceChip,
                    ],
                  ]),
                  if (distance != null && stackDistance)
                    Padding(padding: const EdgeInsets.only(top: 8), child: distanceChip),
                ]);
              }),
              const SizedBox(height: 12),
              Row(children: [
                _photo(doctor, size: 48),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doctor['doctorName']?.toString() ?? '',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: PPClientTheme.ink(context))),
                  if ((doctor['specialization']?.toString() ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(doctor['specialization'].toString(),
                        style: TextStyle(fontSize: 13, height: 1.35,
                            color: PPClientTheme.muted(context))),
                  ],
                ])),
                Icon(Icons.chevron_right, color: PPClientTheme.accent(context)),
              ]),
              const SizedBox(height: 12),
              Divider(height: 1, color: PPClientTheme.border(context)),
              const SizedBox(height: 12),
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _queueMetric('Waiting', '$waiting patients', Icons.groups_rounded, traffic)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: VerticalDivider(width: 1, color: PPClientTheme.border(context))),
                Expanded(child: _queueMetric('Now serving', '#${_number(doctor['nowServing'])}',
                    Icons.person_outline, PPClientTheme.ink(context))),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Widget trailing) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(title, style: TextStyle(fontSize: 21,
          fontWeight: FontWeight.w800, color: PPClientTheme.ink(context)))),
      trailing,
    ]),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: RefreshIndicator(onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero,
        children: [
          if (widget.homeMode) Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 788), child: _header(),
          )),
          Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!widget.homeMode) ...[
                  _locationCard(), const SizedBox(height: 12), _searchField(),
                  const SizedBox(height: 16),
                ],
                if (widget.homeMode) ...[
                  _sectionTitle('Health Services', TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context, isScrollControlled: true,
                      builder: (_) => SafeArea(child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Health Services', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 20), _servicesGrid(closeSheet: true),
                        ]),
                      )),
                    ),
                    child: const Text('See all'),
                  )),
                  _servicesGrid(), const SizedBox(height: 22),
                ],
                _sectionTitle('Doctors Near You', widget.homeMode
                    ? TextButton(onPressed: widget.onFindDoctor, child: const Text('View all'))
                    : Text(_more ? '${_items.length}+ found' : '${_items.length} found',
                        style: TextStyle(color: PPClientTheme.accent(context)))),
                Text(_position == null
                    ? 'Choose GPS for nearest-first results, or search a town.'
                    : 'Nearest to your location',
                    style: TextStyle(fontSize: 12, color: PPClientTheme.muted(context))),
                const SizedBox(height: 14),
                if (_loading || _locating)
                  const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
                if (_failure != null) Container(
                  padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(children: [
                    Text(_failure!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    TextButton(onPressed: () => _load(), child: const Text('Try again')),
                  ]),
                ),
                if (!_loading && !_locating && _failure == null && _items.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No available doctors found. Try another town or search.', textAlign: TextAlign.center)),
                ..._items.map(_doctorCard),
                if (_more) TextButton(onPressed: _loading ? null : () => _load(next: true),
                    child: const Text('Load more doctors')),
              ]),
            ),
          )),
        ],
      ),
    ),
  );
}

class _DoctorDetails extends StatefulWidget {
  const _DoctorDetails({required this.session, required this.doctorId, required this.onProfileRequired});
  final PPClientSession session; final int doctorId; final VoidCallback onProfileRequired;
  @override
  State<_DoctorDetails> createState() => _DoctorDetailsState();
}
class _DoctorDetailsState extends State<_DoctorDetails> {
  Map<String, dynamic>? _data;
  bool _loading = true, _booking = false;
  String? _failure;
  final _id = _requestId(); // Same ID retained after uncertain network failures / double taps.
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _failure = null; });
    try { final data = await widget.session.doctorDetails(widget.doctorId); if (mounted) setState(() { _data = data; }); }
    catch (e) { if (mounted) setState(() { _failure = _error(e); }); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }
  Future<void> _book() async {
    if (_booking) return;
    if (widget.session.profile?['profileComplete'] != true) {
      Navigator.pop(context, false); widget.onProfileRequired(); return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Book today’s queue?'), content: const Text('Your name, mobile number, age and gender will be shared with this medical centre. Queue times may change.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm booking'))]));
    if (confirm != true || !mounted) return;
    setState(() { _booking = true; _failure = null; });
    try {
      final result = await widget.session.bookDoctor(widget.doctorId, _id);
      if (!mounted) return;
      if (result['status'] == 'Cancelled') {
        setState(() { _failure = 'This request was already cancelled. Return to the doctor list to make a new booking.'; });
        return;
      }
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Booking confirmed'),
        content: Text('Your queue number is ${result['queueNo']}.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('View My Queue'))]));
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) setState(() { _failure = _error(e); }); }
    finally { if (mounted) setState(() { _booking = false; }); }
  }
  @override
  Widget build(BuildContext context) {
    final doctor = _data?['doctor'] as Map<String, dynamic>?;
    return Scaffold(appBar: AppBar(title: const Text('Doctor details')), body: ListView(padding: const EdgeInsets.all(24), children: [
      if (_loading) const LinearProgressIndicator(),
      if (doctor != null) ...[
        Text(doctor['doctorName']?.toString() ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        for (final field in ['specialization','qualifications','medicalCenterName','clinicAddress','city','professionalBio','languages','clinicHours','contactNumber'])
          if ((doctor[field]?.toString() ?? '').trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(doctor[field].toString())),
        const SizedBox(height: 20),
        Text('${_data!['waitingCount']} waiting • Now serving ${_data!['nowServing']}',
          style: TextStyle(fontWeight: FontWeight.w700, color: _traffic(_number(_data!['waitingCount']), dark: PPClientTheme.isDark(context)))),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: () => _directions(context, doctor), icon: const Icon(Icons.directions), label: const Text('Directions in Google Maps')),
        FilledButton(onPressed: _booking || _loading ? null : _book, child: Text(_booking ? 'Booking…' : 'Book today’s queue')),
      ],
      if (_failure != null) Padding(padding: const EdgeInsets.all(12), child: Text(_failure!)),
      if (doctor == null && !_loading) TextButton(onPressed: _load, child: const Text('Try again')),
    ]));
  }
}

class PPClientMyQueue extends StatefulWidget {
  const PPClientMyQueue({super.key, required this.session});
  final PPClientSession session;
  @override
  State<PPClientMyQueue> createState() => _MyQueueState();
}
class _MyQueueState extends State<PPClientMyQueue> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false, _more = false, _foreground = true;
  int _page = 1; String? _failure; int? _cancelling;
  Timer? _timer;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && !_loading && _cancelling == null && _page == 1) _load(silent: true);
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { _foreground = state == AppLifecycleState.resumed; }
  @override
  void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  Future<void> _load({bool next = false, bool silent = false}) async {
    if (_loading) { return; }
    _loading = true; if (!silent) setState(() { _failure = null; });
    final page = next ? _page + 1 : 1;
    try {
      final data = await widget.session.myBookings(page: page);
      if (mounted) setState(() { final rows = (data['items'] as List).cast<Map<String, dynamic>>();
        _items = next ? [..._items, ...rows] : rows; _page = page; _more = data['hasMore'] == true; _failure = null; });
    } catch (e) { if (mounted) setState(() { _failure = _error(e); }); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }
  Future<void> _cancel(Map<String, dynamic> booking) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Cancel this booking?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep booking')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking'))]));
    if (confirm != true || !mounted) return;
    setState(() { _cancelling = _number(booking['bookingId']); });
    try { await widget.session.cancelBooking(_cancelling!); await _load(); }
    catch (e) { if (mounted) setState(() { _failure = _error(e); }); }
    finally { if (mounted) setState(() { _cancelling = null; }); }
  }
  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: () => _load(), child: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('My Queue', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8), const Text('Updates every 30 seconds while this screen is open.'),
    if (_loading) const LinearProgressIndicator(),
    if (_failure != null) ...[Text(_failure!), TextButton(onPressed: () => _load(), child: const Text('Try again'))],
    if (!_loading && _items.isEmpty && _failure == null) const Padding(padding: EdgeInsets.all(24), child: Text('You have no bookings yet. Find a doctor to get started.')),
    ..._items.map((b) {
      final day = DateTime.tryParse(b['queueDate']?.toString() ?? '');
      final today = DateUtils.isSameDay(day, DateTime.now());
      return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b['doctorName']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(b['medicalCenterName']?.toString() ?? ''), const SizedBox(height: 12),
        Text('Queue ${b['queueNo']} • ${b['status']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        if (today && ['Waiting', 'Serving'].contains(b['status'])) Text('Now serving ${b['nowServing']} • ${b['peopleAhead']} ahead'),
        Text(day == null ? '' : '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}'),
        TextButton.icon(onPressed: () => _directions(context, b), icon: const Icon(Icons.directions), label: const Text('Directions')),
        if (today && b['status'] == 'Waiting') OutlinedButton(onPressed: _cancelling != null ? null : () => _cancel(b),
          child: Text(_cancelling == _number(b['bookingId']) ? 'Cancelling…' : 'Cancel booking')),
      ])));
    }),
    if (_more) TextButton(onPressed: _loading ? null : () => _load(next: true), child: const Text('Load older bookings')),
  ]));
}
