import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PP Client uses the device's local clock, independently of system dark mode.
class PPClientThemeClock extends ChangeNotifier with WidgetsBindingObserver {
  PPClientThemeClock({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _mode = modeAt(_now());
    _hour = _now().hour;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  final DateTime Function() _now;
  late ThemeMode _mode;
  late int _hour;
  Timer? _timer;
  ThemeMode get mode => _mode;

  static ThemeMode modeAt(DateTime localTime) =>
      localTime.hour >= 6 && localTime.hour < 18
          ? ThemeMode.light
          : ThemeMode.dark;

  void _refresh() {
    final now = _now();
    final next = modeAt(now);
    if (next != _mode || now.hour != _hour) {
      _mode = next;
      _hour = now.hour;
      notifyListeners();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final now = _now();
    final nextMinute = DateTime(
      now.year, now.month, now.day, now.hour, now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      _refresh();
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

abstract final class PPClientTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color ink(BuildContext context) =>
      isDark(context) ? const Color(0xFFF2F6FF) : const Color(0xFF17243D);
  static Color muted(BuildContext context) =>
      isDark(context) ? const Color(0xFFACBED8) : const Color(0xFF596B85);
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF111B29) : Colors.white;
  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF2B405A) : const Color(0xFFDCE6F4);
  static Color accent(BuildContext context) =>
      isDark(context) ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color tint(BuildContext context) =>
      isDark(context) ? const Color(0xFF132D4B) : const Color(0xFFEAF3FF);

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final ink = dark ? const Color(0xFFF2F6FF) : const Color(0xFF17243D);
    final surface = dark ? const Color(0xFF111B29) : Colors.white;
    final outline = dark ? const Color(0xFF2B405A) : const Color(0xFFDCE6F4);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB), brightness: brightness,
    ).copyWith(primary: primary, surface: surface, onSurface: ink);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF090E17) : const Color(0xFFF5F8FF),
      dividerColor: outline,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF090E17) : const Color(0xFFF5F8FF),
        foregroundColor: ink, elevation: 0,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: dark ? const Color(0xFF183B60) : const Color(0xFFE1EDFF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? primary : ink,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700 : FontWeight.w500,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : ink,
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      )),
    );
  }
}
