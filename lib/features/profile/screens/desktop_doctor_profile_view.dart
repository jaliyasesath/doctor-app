import '../../health_posts/doctor_health_posts_screen.dart';
import 'package:flutter/material.dart';

class DesktopDoctorProfileView extends StatelessWidget {
  const DesktopDoctorProfileView({
    super.key,
    required this.profile,
    required this.uploadingKind,
    required this.onRefresh,
    required this.onEdit,
    required this.onOpenMap,
    required this.onMedia,
  });

  final Map<String, dynamic> profile;
  final String? uploadingKind;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onOpenMap;
  final Future<void> Function(String kind) onMedia;

  static const _navy = Color(0xFF0F172A);
  static const _teal = Color(0xFF0F766E);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  String _v(String key) => profile[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final completeness = int.tryParse(_v('profileCompleteness')) ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                sliver: SliverToBoxAdapter(child: _header()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: _identityCard(context, completeness),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                sliver: SliverToBoxAdapter(child: DoctorHealthPostsCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.crossAxisExtent >= 1120;
                    final left = Column(children: [
                      _professionalCard(),
                      const SizedBox(height: 18),
                      _aboutCard(),
                    ]);
                    final right = Column(children: [
                      _centreCard(),
                      const SizedBox(height: 18),
                      _brandingCard(),
                    ]);
                    if (!wide) {
                      return SliverToBoxAdapter(
                        child: Column(children: [
                          left,
                          const SizedBox(height: 18),
                          right,
                        ]),
                      );
                    }
                    return SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: left),
                          const SizedBox(width: 18),
                          Expanded(flex: 9, child: right),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doctor Profile',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _navy)),
              SizedBox(height: 5),
              Text('Manage professional identity, clinic and document branding.',
                  style: TextStyle(color: _muted)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
        ),
      ]);

  Widget _identityCard(BuildContext context, int completeness) {
    final photo = _v('profilePhotoUrl');
    final cover = _v('coverPhotoUrl');
    final verified = _v('verificationStatus').toLowerCase().contains('verified');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => onMedia('cover'),
          child: Container(
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF155E75)],
              ),
              image: cover.isEmpty
                  ? null
                  : DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _mediaAction(
                  uploadingKind == 'cover',
                  cover.isEmpty ? 'Add cover' : 'Change cover',
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
          child: Transform.translate(
            offset: const Offset(0, -38),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              InkWell(
                onTap: () => onMedia('profile'),
                borderRadius: BorderRadius.circular(60),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                    child: uploadingKind == 'profile'
                        ? const CircularProgressIndicator()
                        : photo.isEmpty
                            ? const Icon(Icons.person_rounded, size: 48, color: _muted)
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            _v('doctorName').isEmpty ? 'Doctor profile' : _v('doctorName'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: _navy),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 7),
                          const Tooltip(
                            message: 'Verified identity',
                            child: Icon(Icons.verified_rounded,
                                size: 21, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        [_v('qualifications'), _v('specialization')]
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [_v('slmcRegNo').isEmpty ? '' : 'SLMC ${_v('slmcRegNo')}', _v('city')]
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 235,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Expanded(
                        child: Text('Profile completeness',
                            style: TextStyle(color: _muted, fontSize: 12)),
                      ),
                      Text('$completeness%',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: completeness.clamp(0, 100) / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: _teal,
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _mediaAction(bool loading, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.photo_camera_outlined, size: 17),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _professionalCard() => _card(
        icon: Icons.workspace_premium_outlined,
        title: 'Professional details',
        child: Column(children: [
          _detail('Profession', _v('profession')),
          _detail('Qualifications', _v('qualifications')),
          _detail('Specialization', _v('specialization')),
          _detail('Experience', _v('yearsOfExperience').isEmpty
              ? ''
              : '${_v('yearsOfExperience')} years'),
          _detail('Affiliation', _v('affiliation')),
          _detail('Languages', _v('languages')),
          _detail('Special interests', _v('specialInterests'), last: true),
        ]),
      );

  Widget _aboutCard() => _card(
        icon: Icons.person_outline_rounded,
        title: 'Professional bio',
        child: Text(
          _v('professionalBio').isEmpty ? 'Not added yet' : _v('professionalBio'),
          style: const TextStyle(color: Color(0xFF334155), height: 1.55),
        ),
      );

  Widget _centreCard() {
    final logo = _v('medicalCenterLogoUrl');
    return _card(
      icon: Icons.local_hospital_outlined,
      title: 'Medical centre',
      trailing: TextButton.icon(
        onPressed: onOpenMap,
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('Open map'),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _assetImage(logo, 'logo', size: 84),
        const SizedBox(width: 15),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _v('medicalCenterName').isEmpty
                  ? 'Medical centre not added'
                  : _v('medicalCenterName'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            _iconText(Icons.location_on_outlined, _v('clinicAddress')),
            const SizedBox(height: 6),
            _iconText(Icons.schedule_outlined, _v('clinicHours')),
            const SizedBox(height: 6),
            _iconText(Icons.language_outlined, _v('websiteUrl')),
          ]),
        ),
      ]),
    );
  }

  Widget _brandingCard() => _card(
        icon: Icons.branding_watermark_outlined,
        title: 'Documents & branding',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'These verified assets are reused on prescriptions, PDFs and laboratory emails.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _assetTile('Centre logo', _v('medicalCenterLogoUrl'), 'logo')),
            const SizedBox(width: 12),
            Expanded(child: _assetTile('Doctor signature', _v('signatureImageUrl'), 'signature')),
          ]),
        ]),
      );

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _teal, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
            ),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 17),
          child,
        ]),
      );

  Widget _detail(String label, String value, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 145,
            child: Text(label, style: const TextStyle(color: _muted)),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'Not added' : value,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          ),
        ]),
      );

  Widget _iconText(IconData icon, String value) => Row(children: [
        Icon(icon, size: 17, color: _muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(value.isEmpty ? 'Not added' : value,
              style: const TextStyle(color: _muted), overflow: TextOverflow.ellipsis),
        ),
      ]);

  Widget _assetImage(String url, String kind, {double size = 76}) => InkWell(
        onTap: () => onMedia(kind),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _border),
          ),
          child: uploadingKind == kind
              ? const Padding(
                  padding: EdgeInsets.all(20), child: CircularProgressIndicator())
              : url.isEmpty
                  ? const Icon(Icons.add_photo_alternate_outlined, color: _teal)
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, color: _muted),
                    ),
        ),
      );

  Widget _assetTile(String title, String url, String kind) => InkWell(
        onTap: () => onMedia(kind),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Expanded(child: _assetImage(url, kind, size: 66)),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
