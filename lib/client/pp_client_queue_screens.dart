import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pp_client_config.dart';
import 'pp_client_session.dart';

String _error(Object e) => e is PPClientError ? e.message : 'Unable to load this information. Please try again.';
Color _traffic(int count) => count <= 10 ? const Color(0xFF178953) : count < 20 ? const Color(0xFFD77B0B) : const Color(0xFFCC3737);
int _number(dynamic value) => value is num ? value.toInt() : 0;
String _requestId() {
  final random = Random.secure(); final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
}
Widget _photo(Map<String, dynamic> doctor) {
  final value = doctor['profilePhotoUrl']?.toString() ?? '';
  Uri? uri;
  if (value.isNotEmpty) {
    final origin = PPClientConfig.origin.toString().replaceAll(RegExp(r'/+$'), '');
    uri = Uri.parse('$origin/').resolve(value);
  }
  return ClipOval(child: SizedBox(width: 58, height: 58, child: uri != null &&
    (uri.scheme == 'https' || (uri.scheme == 'http' && uri.host == PPClientConfig.origin.host))
      ? Image.network(uri.toString(), fit: BoxFit.cover, cacheWidth: 144,
          errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 38, color: Color(0xFF078A55)))
      : const Icon(Icons.person_rounded, size: 38, color: Color(0xFF078A55))));
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
          const Icon(Icons.health_and_safety_outlined, size: 64, color: Color(0xFF078A55)),
          const SizedBox(height: 22), Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12), Text(description, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 24), OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Home')),
        ]))))));
  }

  Widget _header() {
    final name = widget.session.profile?['fullName']?.toString().trim() ?? '';
    final firstName = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1AB75B), Color(0xFF00955D), Color(0xFF007F52)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
      child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 38),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(5),
              child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.health_and_safety, color: Color(0xFF078A55), size: 36))),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PP Client', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('Care Starts with a Tap', style: TextStyle(fontSize: 12, color: Colors.white))])),
            IconButton(tooltip: 'Notifications', onPressed: () => _service('Notifications',
              'Queue alerts will be available when the notification service is connected. You can check your current status in My Queue.'),
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28)),
            IconButton.filledTonal(tooltip: 'Your profile', onPressed: widget.onProfile,
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFE4F6EA)),
              icon: const Icon(Icons.person_rounded, color: Color(0xFF078A55))),
          ]),
          const SizedBox(height: 26),
          Text('Hi $firstName,', style: const TextStyle(fontSize: 20, color: Colors.white)),
          const SizedBox(height: 7),
          const Text('How can we help you today?', style: TextStyle(fontSize: 24,
            height: 1.2, fontWeight: FontWeight.w800, color: Colors.white)),
        ]))),
    );
  }

  Widget _locationCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDFECE4)),
      boxShadow: const [BoxShadow(color: Color(0x09004122), blurRadius: 15, offset: Offset(0, 5))]),
    child: Row(children: [
      const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE6F5EC),
        child: Icon(Icons.location_on_rounded, color: Color(0xFF078A55), size: 29)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your location', style: TextStyle(fontSize: 12, color: Color(0xFF798394))),
        const SizedBox(height: 4),
        Text(_locating ? 'Finding your location…' : _town ?? (_position == null ? 'Choose your location' : 'Current GPS location'),
          style: const TextStyle(color: Color(0xFF192641), fontWeight: FontWeight.w700, fontSize: 15)),
      ])),
      TextButton(onPressed: _locating ? null : _changeLocation, child: const Text('Change')),
      const Icon(Icons.chevron_right, size: 18, color: Color(0xFF078A55)),
    ]),
  );

  Widget _servicesGrid({bool closeSheet = false}) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 560 ? 3 : constraints.maxWidth >= 300 ? 3 : 2;
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final items = <({IconData icon, String title, String subtitle, VoidCallback action})>[
      (icon: Icons.person_search_rounded, title: 'Find Doctor', subtitle: 'Book your queue', action: () => widget.onFindDoctor?.call()),
      (icon: Icons.storefront_rounded, title: 'Find Pharmacy', subtitle: 'Nearby pharmacies', action: () => _service('Find Pharmacy', 'Pharmacy search is not available yet. Verified pharmacy listings will be added in the pharmacy module.')),
      (icon: Icons.article_outlined, title: 'Medical News', subtitle: 'Health tips & updates', action: () => _service('Medical News', 'Medical news will be available when the content service is connected.')),
      (icon: Icons.science_outlined, title: 'Lab Search', subtitle: 'Find test centres', action: () => _service('Lab Search', 'Laboratory search is not available yet. Verified laboratory listings will be added in the laboratory module.')),
      (icon: Icons.confirmation_number_outlined, title: 'My Queue', subtitle: 'View your queue', action: () => widget.onMyQueue?.call()),
      (icon: Icons.health_and_safety_rounded, title: 'Health Records', subtitle: 'Coming soon', action: () => _service('Health Records', 'Your health records are not available in PP Client yet. Secure record access will be added in the health records module.')),
    ];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
      itemCount: items.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 152 * scale.clamp(1, 1.7)),
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21),
          side: const BorderSide(color: Color(0xFFDFECE4))), clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: () { if (closeSheet) Navigator.pop(context); item.action(); }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 25, backgroundColor: const Color(0xFFE7F5ED),
                child: Icon(item.icon, color: const Color(0xFF078A55), size: 29)),
              const SizedBox(height: 10),
              Text(item.title, textAlign: TextAlign.center, maxLines: 2,
                style: const TextStyle(fontSize: 13, color: Color(0xFF192641), fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(item.subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.3, color: Color(0xFF7A8390))),
            ]))));
      });
  });

  Future<void> _openDoctor(Map<String, dynamic> doctor) async {
    final booked = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _DoctorDetails(
      session: widget.session, doctorId: _number(doctor['doctorId']), onProfileRequired: widget.onProfileRequired)));
    if (booked == true && mounted) widget.onBooked();
  }

  Widget _doctorCard(Map<String, dynamic> doctor) {
    final waiting = _number(doctor['waitingCount']); final color = _traffic(waiting);
    final clinic = doctor['medicalCenterName']?.toString() ?? '';
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFDFECE4))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => _openDoctor(doctor), child: Padding(padding: const EdgeInsets.all(15),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(decoration: const BoxDecoration(color: Color(0xFFE5F4EB), shape: BoxShape.circle),
              padding: const EdgeInsets.all(5), child: _photo(doctor)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doctor['doctorName']?.toString() ?? '', style: const TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: Color(0xFF192641))),
              const SizedBox(height: 4),
              Text(doctor['specialization']?.toString() ?? '', style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: Color(0xFF078A55))),
              const SizedBox(height: 4),
              Text(clinic, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8390))),
            ])),
            if (doctor['distanceKm'] != null) Padding(padding: const EdgeInsets.only(left: 6), child: Column(children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFF078A55), size: 23),
              Text('${doctor['distanceKm']} km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
          ]),
          const SizedBox(height: 13),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: color.withValues(alpha: .075), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [Icon(Icons.groups_rounded, color: color, size: 21), const SizedBox(width: 7),
              Expanded(child: Text('$waiting waiting', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800))),
              Container(height: 22, width: 1, color: const Color(0xFFCEDDD5)), const SizedBox(width: 10),
              Flexible(child: Text('Now serving: ${_number(doctor['nowServing'])}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF798394)))),
              const SizedBox(width: 5), const Icon(Icons.chevron_right, color: Color(0xFF078A55), size: 20),
            ])),
        ])))));
  }

  Widget _sectionTitle(String title, Widget trailing) => Padding(padding: const EdgeInsets.only(bottom: 15),
    child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 21,
      fontWeight: FontWeight.w800, color: Color(0xFF192641)))), trailing]));

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: () => _load(),
    child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero, children: [
      if (widget.homeMode) _header(),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Padding(
        padding: EdgeInsets.fromLTRB(18, widget.homeMode ? 0 : 10, 18, 24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.homeMode) ...[
              Transform.translate(offset: const Offset(0, -19), child: _locationCard()),
            ] else ...[
              const Text('Doctors near you', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF192641))),
              const SizedBox(height: 14), _locationCard(), const SizedBox(height: 20),
            ],
            TextField(controller: _search, maxLength: 100, textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(counterText: '', hintText: 'Search doctor, specialty or town',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF798394)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF798394)),
                suffixIcon: IconButton(tooltip: 'Search', onPressed: _loading ? null : () => _load(),
                  icon: const Icon(Icons.tune_rounded, color: Color(0xFF078A55))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(21), borderSide: const BorderSide(color: Color(0xFFDFECE4))),
                contentPadding: const EdgeInsets.symmetric(vertical: 19))),
            const SizedBox(height: 25),
            if (widget.homeMode) ...[
              _sectionTitle('Health Services', TextButton(onPressed: () {
                showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheet) => SafeArea(
                  child: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Health Services', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 20), _servicesGrid(closeSheet: true),
                    ])))));
              }, child: const Text('View all'))),
              _servicesGrid(), const SizedBox(height: 28),
            ],
            _sectionTitle('Doctors Near You', Text(_more ? '${_items.length}+ found' : '${_items.length} found',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF078A55)))),
            Text(_position == null ? 'Choose GPS for nearest-first results, or search a town.' : 'Nearest first • Latest server queue counts',
              style: const TextStyle(fontSize: 12, color: Color(0xFF798394))),
            const SizedBox(height: 12),
            if (_loading || _locating) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
            if (_failure != null) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFFFF0EA), borderRadius: BorderRadius.circular(18)),
              child: Column(children: [Text(_failure!), TextButton(onPressed: () => _load(), child: const Text('Try again'))])),
            if (!_loading && !_locating && _failure == null && _items.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No available doctors found. Try another town or search.', textAlign: TextAlign.center)),
            ..._items.map(_doctorCard),
            if (_more) TextButton(onPressed: _loading ? null : () => _load(next: true), child: const Text('Load more doctors')),
          ])))),
    ]));
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
          style: TextStyle(fontWeight: FontWeight.w700, color: _traffic(_number(_data!['waitingCount'])))),
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
    if (_loading) return;
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
