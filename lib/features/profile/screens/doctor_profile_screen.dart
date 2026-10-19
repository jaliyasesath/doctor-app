import 'package:doctor_app/features/centres/centre_hours_screen.dart';
import '../../health_posts/doctor_health_posts_screen.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_error_ui.dart';
import '../../auth/data/doctor_session.dart';
import '../data/doctor_profile_api_service.dart';
import 'desktop_doctor_profile_view.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  static const _teal = Color(0xFF0F766E);
  final _api = DoctorProfileApiService();
  final _picker = ImagePicker();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _uploadingKind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _api.getProfile();
      await DoctorSession.saveProfilePhotoUrl(
        profile['profilePhotoUrl']?.toString() ?? '',
      );
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _v(String key) => _profile?[key]?.toString() ?? '';
  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _pickMedia(String kind, ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: kind == 'cover' ? 1800 : 1000,
    );
    if (image == null || !mounted) return;
    setState(() => _uploadingKind = kind);
    try {
      await _api.uploadMedia(kind, image.path);
      await _load();
      if (mounted) _message('${_kindLabel(kind)} updated');
    } catch (error) {
      if (mounted) {
        AppErrorUi.show(
          context,
          error,
          onRetry: () => _pickMedia(kind, source),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingKind = null);
    }
  }

  Future<void> _removeMedia(String kind) async {
    try {
      await _api.removeMedia(kind);
      await _load();
      if (mounted) _message('${_kindLabel(kind)} removed');
    } catch (error) {
      if (mounted) {
        AppErrorUi.show(context, error, onRetry: () => _removeMedia(kind));
      }
    }
  }

  String _kindLabel(String kind) => switch (kind) {
    'profile' => 'Profile photo',
    'cover' => 'Cover photo',
    'logo' => 'Medical centre logo',
    _ => 'Signature',
  };

  Future<void> _mediaMenu(String kind) async {
    final hasImage = _v(switch (kind) {
      'profile' => 'profilePhotoUrl',
      'cover' => 'coverPhotoUrl',
      'logo' => 'medicalCenterLogoUrl',
      _ => 'signatureImageUrl',
    }).isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasImage ? 'Replace image' : 'Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (kind == 'profile' && !Platform.isWindows)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove image'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == 'gallery') await _pickMedia(kind, ImageSource.gallery);
    if (action == 'camera') await _pickMedia(kind, ImageSource.camera);
    if (action == 'remove') await _removeMedia(kind);
  }

  Future<void> _edit() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _DoctorProfileEditScreen(
          initial: Map<String, dynamic>.from(profile),
          api: _api,
        ),
      ),
    );
    if (updated == true) {
      setState(() => _loading = true);
      await _load();
      if (mounted) _message('Profile updated');
    }
  }

  Future<void> _openMap() async {
    final lat = _v('medicalCenterLatitude');
    final lon = _v('medicalCenterLongitude');
    if (lat.isEmpty || lon.isEmpty) {
      _message('Add the medical centre GPS location first');
      return;
    }
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Profile')),
        body: const Center(child: Text('Profile unavailable')),
      );
    }
    final photo = _v('profilePhotoUrl');
    final cover = _v('coverPhotoUrl');
    final logo = _v('medicalCenterLogoUrl');
    final completeness = int.tryParse(_v('profileCompleteness')) ?? 0;
    final useDesktopLayout =
        Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000;
    if (useDesktopLayout) {
      return DesktopDoctorProfileView(
        profile: _profile!,
        uploadingKind: _uploadingKind,
        onRefresh: _load,
        onEdit: _edit,
        onOpenMap: _openMap,
        onMedia: _mediaMenu,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _edit,
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _mediaMenu('cover'),
                  child: Container(
                    height: 190,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_teal, Color(0xFF164E63)],
                      ),
                      image: cover.isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(cover),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: _uploadingKind == 'cover'
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: CircleAvatar(
                                child: Icon(Icons.camera_alt_outlined),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  left: 22,
                  bottom: -60,
                  child: GestureDetector(
                    onTap: () => _mediaMenu('profile'),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: photo.isEmpty
                            ? null
                            : NetworkImage(photo),
                        child: _uploadingKind == 'profile'
                            ? const CircularProgressIndicator()
                            : photo.isEmpty
                            ? const Icon(Icons.person, size: 56)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 72, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _v('doctorName'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_v(
                        'verificationStatus',
                      ).toLowerCase().contains('verified'))
                        const Icon(Icons.verified, color: Color(0xFF2563EB)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _v('qualifications'),
                      _v('specialization'),
                    ].where((x) => x.isNotEmpty).join(' · '),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'SLMC ${_v('slmcRegNo')} · ${_v('city')}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: completeness / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$completeness% complete',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [DoctorHealthPostsCard(), CentreHoursCard()],
              ),
            ),
            _section('About', _v('professionalBio'), Icons.person_outline),
            _detailsCard(),
            _centreCard(logo),
            _brandingCard(logo),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.workspace_premium_outlined,
            title: 'Professional details',
          ),
          _row('Profession', _v('profession')),
          _row('Qualifications', _v('qualifications')),
          _row(
            'Experience',
            _v('yearsOfExperience').isEmpty
                ? ''
                : '${_v('yearsOfExperience')} years',
          ),
          _row('Affiliation', _v('affiliation')),
          _row('Languages', _v('languages')),
          _row('Special interests', _v('specialInterests')),
        ],
      ),
    ),
  );

  Widget _centreCard(String logo) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.local_hospital_outlined,
            title: 'Medical centre',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _mediaMenu('logo'),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _uploadingKind == 'logo'
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(),
                        )
                      : logo.isEmpty
                      ? const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _teal,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(logo, fit: BoxFit.contain),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _v('medicalCenterName').isEmpty
                          ? 'Medical centre not added'
                          : _v('medicalCenterName'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_v('clinicAddress')),
                    Text(
                      _v('clinicHours'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open map'),
              ),
              OutlinedButton.icon(
                onPressed: () => _mediaMenu('logo'),
                icon: const Icon(Icons.image_outlined),
                label: Text(logo.isEmpty ? 'Add logo' : 'Change logo'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _brandingCard(String logo) {
    final signature = _v('signatureImageUrl');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.branding_watermark_outlined,
              title: 'Documents & branding',
            ),
            const Text(
              'These assets are reused on prescriptions, PDFs and laboratory emails.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _assetTile('Centre logo', logo, 'logo')),
                const SizedBox(width: 10),
                Expanded(
                  child: _assetTile('Doctor signature', signature, 'signature'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetTile(String title, String url, String kind) => InkWell(
    onTap: () => _mediaMenu(kind),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: url.isEmpty
                ? const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 38,
                    color: _teal,
                  )
                : Image.network(url, fit: BoxFit.contain),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );

  Widget _section(String title, String value, IconData icon) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, title: title),
          Text(
            value.isEmpty ? 'Not added yet' : value,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not added' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF0F766E)),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ],
    ),
  );
}

class _DoctorProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DoctorProfileApiService api;
  const _DoctorProfileEditScreen({required this.initial, required this.api});
  @override
  State<_DoctorProfileEditScreen> createState() =>
      _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<_DoctorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  static const _fields = [
    'doctorName',
    'contactNumber',
    'specialization',
    'medicalCenterName',
    'clinicAddress',
    'city',
    'qualifications',
    'profession',
    'affiliation',
    'professionalBio',
    'languages',
    'specialInterests',
    'clinicHours',
    'websiteUrl',
    'yearsOfExperience',
  ];

  @override
  void initState() {
    super.initState();
    _c = {
      for (final key in _fields)
        key: TextEditingController(text: widget.initial[key]?.toString() ?? ''),
    };
    _latitude = double.tryParse(
      widget.initial['medicalCenterLatitude']?.toString() ?? '',
    );
    _longitude = double.tryParse(
      widget.initial['medicalCenterLongitude']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        for (final entry in _c.entries) entry.key: entry.value.text.trim(),
      };
      payload['yearsOfExperience'] = int.tryParse(
        _c['yearsOfExperience']!.text.trim(),
      );
      payload['profilePhotoUrl'] = widget.initial['profilePhotoUrl'] ?? '';
      payload['coverPhotoUrl'] = widget.initial['coverPhotoUrl'] ?? '';
      payload['medicalCenterLogoUrl'] =
          widget.initial['medicalCenterLogoUrl'] ?? '';
      payload['signatureImageUrl'] = widget.initial['signatureImageUrl'] ?? '';
      payload['medicalCenterLatitude'] = _latitude;
      payload['medicalCenterLongitude'] = _longitude;
      payload['expectedVersion'] = widget.initial['version'];
      await widget.api.updateProfile(payload);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error, onRetry: _save);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final useDesktopLayout =
        Platform.isWindows && MediaQuery.sizeOf(context).width >= 1000;
    if (useDesktopLayout) return _desktopBuild(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heading('Professional identity'),
            _field('doctorName', 'Doctor name', required: true),
            _field(
              'contactNumber',
              'Contact number',
              keyboard: TextInputType.phone,
            ),
            _field('qualifications', 'Qualifications'),
            _field('profession', 'Profession'),
            _field('specialization', 'Specialization'),
            _field(
              'yearsOfExperience',
              'Years of experience',
              keyboard: TextInputType.number,
            ),
            _field('affiliation', 'Professional affiliation'),
            _field('professionalBio', 'Professional bio', lines: 4),
            _field('languages', 'Languages'),
            _field('specialInterests', 'Special interests', lines: 2),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline),
              title: Text('SLMC number and verified email are protected'),
              subtitle: Text(
                'Use the verified identity change process to update these fields.',
              ),
            ),
            _heading('Medical centre'),
            _field('medicalCenterName', 'Medical centre name'),
            _field('clinicAddress', 'Clinic address', lines: 2),
            _field('city', 'City'),
            _field('clinicHours', 'Clinic hours', lines: 2),
            _field('websiteUrl', 'Website', keyboard: TextInputType.url),
            OutlinedButton.icon(
              onPressed: _locate,
              icon: const Icon(Icons.my_location),
              label: const Text('Use current GPS location'),
            ),
            if (_latitude != null && _longitude != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'GPS: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save profile'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _desktopBuild(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to profile',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Doctor Profile',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Update professional and medical centre information.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _desktopCard(
                        'Professional identity',
                        Icons.workspace_premium_outlined,
                        [
                          _desktopField(
                            'doctorName',
                            'Doctor name',
                            required: true,
                          ),
                          _desktopPair(
                            _field(
                              'contactNumber',
                              'Contact number',
                              keyboard: TextInputType.phone,
                            ),
                            _field(
                              'yearsOfExperience',
                              'Years of experience',
                              keyboard: TextInputType.number,
                            ),
                          ),
                          _desktopPair(
                            _field('qualifications', 'Qualifications'),
                            _field('profession', 'Profession'),
                          ),
                          _field('specialization', 'Specialization'),
                          _field('affiliation', 'Professional affiliation'),
                          _field(
                            'professionalBio',
                            'Professional bio',
                            lines: 4,
                          ),
                          _desktopPair(
                            _field('languages', 'Languages'),
                            _field(
                              'specialInterests',
                              'Special interests',
                              lines: 2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'SLMC number and verified email are protected by the identity change process.',
                                    style: TextStyle(color: Color(0xFF1E3A8A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _desktopCard(
                        'Medical centre',
                        Icons.local_hospital_outlined,
                        [
                          _field('medicalCenterName', 'Medical centre name'),
                          _field('clinicAddress', 'Clinic address', lines: 3),
                          _desktopPair(
                            _field('city', 'City'),
                            _field(
                              'websiteUrl',
                              'Website',
                              keyboard: TextInputType.url,
                            ),
                          ),
                          _field('clinicHours', 'Clinic hours', lines: 3),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _locate,
                            icon: const Icon(Icons.my_location_rounded),
                            label: const Text('Use current GPS location'),
                          ),
                          if (_latitude != null && _longitude != null)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFF0F766E),
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _desktopCard(String title, IconData icon, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF0F766E), size: 21),
                ),
                const SizedBox(width: 11),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );

  Widget _desktopPair(Widget left, Widget right) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );

  Widget _desktopField(String key, String label, {bool required = false}) =>
      _field(key, label, required: required);

  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 12),
    child: Text(
      value,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F766E),
      ),
    ),
  );
  Widget _field(
    String key,
    String label, {
    int lines = 1,
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c[key],
      maxLines: lines,
      keyboardType: keyboard,
      validator: (value) => _validateField(key, label, value, required),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  String? _validateField(
    String key,
    String label,
    String? value,
    bool required,
  ) {
    final text = value?.trim() ?? '';
    if (required && text.isEmpty) return '$label is required';
    if (text.isEmpty) return null;

    final limits = <String, int>{
      'doctorName': 200,
      'contactNumber': 30,
      'specialization': 200,
      'medicalCenterName': 200,
      'clinicAddress': 500,
      'city': 100,
      'qualifications': 500,
      'profession': 200,
      'affiliation': 500,
      'professionalBio': 2000,
      'languages': 500,
      'specialInterests': 1000,
      'clinicHours': 500,
      'websiteUrl': 500,
    };
    final limit = limits[key];
    if (limit != null && text.length > limit) {
      return '$label must be $limit characters or fewer';
    }
    if (key == 'yearsOfExperience') {
      final years = int.tryParse(text);
      if (years == null || years < 0 || years > 80) {
        return 'Enter a value between 0 and 80';
      }
    }
    if (key == 'websiteUrl') {
      final uri = Uri.tryParse(text);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return 'Use a complete URL such as https://example.com';
      }
    }
    return null;
  }
}
