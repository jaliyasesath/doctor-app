import 'package:flutter/material.dart';

/// Windows presentation only; authentication remains owned by each screen.
class DesktopAuthFrame extends StatelessWidget {
  const DesktopAuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxWidth = 520,
    this.onBack,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double maxWidth;
  final VoidCallback? onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7F7),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: onBack == null
              ? null
              : IconButton(
                  tooltip: 'Back',
                  onPressed: busy ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
          title: const Text('PP App'),
          backgroundColor: const Color(0xFF09213C),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE0E8EB)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 600 ? 20 : 32,
                      ),
                      child: Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: const Color(0xFF0F766E),
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Icon(Icons.local_hospital_rounded,
                                  size: 38, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 16),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.w800,
                                    color: Color(0xFF09213C))),
                            const SizedBox(height: 8),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Color(0xFF64748B), height: 1.5)),
                            const SizedBox(height: 24),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
