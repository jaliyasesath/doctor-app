import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/doctor_profile_api_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});
  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _api = DoctorProfileApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final p = await _api.getProfile(); if (mounted) setState(() => _profile = p); }
    catch (e) { if (mounted) _message('Unable to load profile: $e'); }
    finally { if (mounted) setState(() => _loading = false); } }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  String _v(String key) => _profile?[key]?.toString() ?? '';

  Future<void> _edit() async {
    if (_profile == null) return;
    final keys = ['doctorName', 'contactNumber', 'specialization', 'medicalCenterName', 'clinicAddress', 'city',
      'qualifications', 'profession', 'affiliation', 'professionalBio', 'languages', 'specialInterests', 'clinicHours',
      'websiteUrl', 'profilePhotoUrl', 'coverPhotoUrl'];
    final controllers = {for (final key in keys) key: TextEditingController(text: _v(key))};
    double? latitude = double.tryParse(_v('medicalCenterLatitude'));
    double? longitude = double.tryParse(_v('medicalCenterLongitude'));

    final data = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> locate() async {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
          final p = await Geolocator.getCurrentPosition();
          setDialogState(() { latitude = p.latitude; longitude = p.longitude; });
        }
        return AlertDialog(title: const Text('Edit Professional Profile'), content: SizedBox(width: 600,
          child: SingleChildScrollView(child: Column(children: [
            _field(controllers['doctorName']!, 'Doctor name *'), _field(controllers['contactNumber']!, 'Contact number'),
            _field(controllers['specialization']!, 'Specialization'), _field(controllers['qualifications']!, 'Qualifications'),
            _field(controllers['profession']!, 'Profession'), _field(controllers['affiliation']!, 'Affiliation'),
            _field(controllers['professionalBio']!, 'Professional bio', 4), _field(controllers['languages']!, 'Languages'),
            _field(controllers['specialInterests']!, 'Special interests', 2), const Divider(),
            _field(controllers['medicalCenterName']!, 'Medical centre'), _field(controllers['clinicAddress']!, 'Clinic address', 2),
            _field(controllers['city']!, 'City'), _field(controllers['clinicHours']!, 'Clinic hours'),
            _field(controllers['websiteUrl']!, 'Website'),
            OutlinedButton.icon(onPressed: locate, icon: const Icon(Icons.my_location), label: const Text('Use current location')),
            if (latitude != null && longitude != null) Text('${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'),
            const Divider(), _field(controllers['profilePhotoUrl']!, 'Profile photo URL'), _field(controllers['coverPhotoUrl']!, 'Cover photo URL'),
            const ListTile(leading: Icon(Icons.verified_user), title: Text('SLMC number and verification cannot be edited here')),
          ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (controllers['doctorName']!.text.trim().isEmpty) return;
            Navigator.pop(context, {for (final entry in controllers.entries) entry.key: entry.value.text.trim(),
              'medicalCenterLatitude': latitude, 'medicalCenterLongitude': longitude, 'expectedVersion': _profile!['version']}); }, child: const Text('Save'))]);
      }));
    for (final c in controllers.values) { c.dispose(); }
    if (data == null) return;
    try { await _api.updateProfile(data); setState(() => _loading = true); await _load(); if (mounted) _message('Profile updated'); }
    catch (e) { if (mounted) _message('Update failed: $e'); }
  }

  static Widget _field(TextEditingController c, String label, [int lines = 1]) => Padding(
    padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, maxLines: lines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));

  Future<void> _openMap() async {
    final lat = _v('medicalCenterLatitude'), lon = _v('medicalCenterLongitude');
    if (lat.isEmpty || lon.isEmpty) return;
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = _profile;
    if (p == null) return Scaffold(appBar: AppBar(title: const Text('Profile')), body: const Center(child: Text('Profile unavailable')));
    final photo = _v('profilePhotoUrl'); final cover = _v('coverPhotoUrl');
    return Scaffold(appBar: AppBar(title: const Text('Professional Profile'), actions: [IconButton(onPressed: _edit, icon: const Icon(Icons.edit))]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(children: [
        Container(height: 160, decoration: BoxDecoration(color: const Color(0xFF0F766E),
          image: cover.isEmpty ? null : DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover))),
        Transform.translate(offset: const Offset(0, -52), child: Column(children: [
          CircleAvatar(radius: 58, backgroundColor: Colors.white, child: CircleAvatar(radius: 53,
            backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? const Icon(Icons.person, size: 58) : null)),
          Text(_v('doctorName'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(_v('specialization')), const SizedBox(height: 5),
          Chip(avatar: const Icon(Icons.verified, size: 18), label: Text('${_v('verificationStatus')} • SLMC ${_v('slmcRegNo')}')),
        ])),
        _section('About', _v('professionalBio')), _section('Qualifications', '${_v('qualifications')}\n${_v('profession')}'),
        _section('Languages', _v('languages')), _section('Special interests', _v('specialInterests')),
        Card(margin: const EdgeInsets.all(16), child: ListTile(leading: const Icon(Icons.local_hospital),
          title: Text(_v('medicalCenterName')), subtitle: Text('${_v('clinicAddress')}\n${_v('clinicHours')}'), isThreeLine: true,
          trailing: IconButton(onPressed: _openMap, icon: const Icon(Icons.map)))),
        const SizedBox(height: 40),
      ])));
  }

  Widget _section(String title, String value) => Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 7), Text(value.isEmpty ? 'Not added' : value)])));
}
