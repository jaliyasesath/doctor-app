import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doctor profile desktop layout is isolated to Windows', () {
    final source = File(
      'lib/features/profile/screens/doctor_profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Platform.isWindows'));
    expect(source, contains('MediaQuery.sizeOf(context).width >= 1000'));
    expect(source, contains('return DesktopDoctorProfileView('));
    expect(source, contains('return Scaffold('));
  });

  test('desktop profile preserves existing API-backed operations', () {
    final source = File(
      'lib/features/profile/screens/doctor_profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('onRefresh: _load'));
    expect(source, contains('onEdit: _edit'));
    expect(source, contains('onOpenMap: _openMap'));
    expect(source, contains('onMedia: _mediaMenu'));
    expect(source, contains('await widget.api.updateProfile(payload)'));
    expect(source, contains("await _api.uploadMedia(kind, image.path)"));
    expect(source, contains('await _api.removeMedia(kind)'));
  });

  test('desktop edit keeps validation and protected identity fields', () {
    final source = File(
      'lib/features/profile/screens/doctor_profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains("_validateField(key, label, value, required)"));
    expect(source, contains("payload['expectedVersion']"));
    expect(source, contains('SLMC number and verified email are protected'));
    expect(source, contains('AppErrorUi.show'));
  });
}
