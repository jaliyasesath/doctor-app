import 'dart:math' as math;

import 'package:flutter/material.dart';

class DesktopLoginLayout extends StatelessWidget {
  const DesktopLoginLayout({super.key, required this.child, this.busy = false});

  final Widget child;
  final bool busy;
  static const _ink = Color(0xFF0F172A);
  static const _teal = Color(0xFF0F766E);

  Widget _logo({bool light = false}) => Row(children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/private_practices_logo.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.local_hospital_rounded, color: _teal)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Private Practices',
                style: TextStyle(color: light ? Colors.white : _ink,
                    fontSize: 25, letterSpacing: -0.4, fontWeight: FontWeight.w800)),
            Text('Care starts with a tap.',
                style: TextStyle(color: light ? const Color(0xFFD5FAF7)
                    : const Color(0xFF64748B), fontSize: 10,
                    letterSpacing: 0.3, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]);

  Widget _feature(IconData icon, String title, String description) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0x26064E3B),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: const Color(0xFFD5FAF7)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(
                  color: Color(0xFFD5FAF7), fontSize: 12, height: 1.5)),
            ],
          )),
        ]),
      );

  Widget _brandPanel() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF075E54), _teal, Color(0xFF22A06B)]),
        ),
        padding: const EdgeInsets.all(42),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _logo(light: true),
          const SizedBox(height: 70),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0x6699F6E4)),
                borderRadius: BorderRadius.circular(30)),
            child: const Text('BUILT FOR YOUR DAILY PRACTICE',
                style: TextStyle(color: Color(0xFFD5FAF7), fontSize: 9,
                    letterSpacing: 1.3, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 22),
          const Text('Your practice.\nOne workspace.',
              style: TextStyle(color: Colors.white, fontSize: 38,
                  height: 1.16, letterSpacing: -1.1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          const Text('Keep your clinic organised, from the first patient to the final prescription.',
              style: TextStyle(color: Color(0xFFD5FAF7), fontSize: 14, height: 1.7)),
          const SizedBox(height: 18),
          _feature(Icons.people_outline_rounded, 'Patient care',
              'Patient records and visit history.'),
          _feature(Icons.receipt_long_outlined, 'Prescriptions',
              'Create, review and print prescriptions.'),
          _feature(Icons.insights_outlined, 'Practice overview',
              'Queue, billing and clinic analytics.'),
          const SizedBox(height: 48),
          const Divider(color: Color(0x6699F6E4)),
          const SizedBox(height: 14),
          const Text('PRIVATE PRACTICE  /  WINDOWS',
              style: TextStyle(color: Color(0xFFD5FAF7), fontSize: 10,
                  letterSpacing: 1.1)),
        ]),
      );

  Widget _formPanel(bool wide) => Padding(
        padding: EdgeInsets.all(wide ? 52 : 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!wide) ...[_logo(), const SizedBox(height: 36)],
          const Text('ACCOUNT ACCESS', style: TextStyle(color: _teal,
              fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text('Welcome back', style: TextStyle(color: _ink,
              fontSize: 32, letterSpacing: -.8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('Enter your details to continue to your practice.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.6)),
          const SizedBox(height: 32),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)));
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final padding = constraints.maxWidth < 600 ? 12.0 : 32.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: math.max(0.0, constraints.maxHeight - padding * 2)),
              child: Center(child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1120 : 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Color(0x1A064E3B),
                        blurRadius: 48, offset: Offset(0, 16))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Theme(
                      data: theme.copyWith(
                        colorScheme: theme.colorScheme.copyWith(primary: _teal),
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true, fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 19),
                          border: border, enabledBorder: border,
                          focusedBorder: border.copyWith(borderSide:
                              const BorderSide(color: _teal, width: 1.5)),
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        filledButtonTheme: FilledButtonThemeData(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      child: wide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 46, child: _brandPanel()),
                                Expanded(flex: 54, child: _formPanel(true)),
                              ])
                          : _formPanel(false),
                    ),
                  ),
                ),
              )),
            ),
          );
        })),
      ),
    );
  }
}
