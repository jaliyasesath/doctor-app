/// Display-only formatting. Stored doctor names remain unchanged.
String ppClientDoctorName(Object? value) {
  final name = value?.toString().trim() ?? '';
  if (name.isEmpty) return 'Doctor';
  if (RegExp(r'^dr(?:\.\s*|\s+)', caseSensitive: false).hasMatch(name)) {
    return 'Dr. ${name.replaceFirst(RegExp(r'^dr(?:\.\s*|\s+)', caseSensitive: false), '').trim()}';
  }
  return 'Dr. $name';
}

String? ppClientPhotoUrl(Object? value) {
  final uri = Uri.tryParse(value?.toString().trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.hasAuthority &&
      uri.userInfo.isEmpty ? uri.toString() : null;
}
