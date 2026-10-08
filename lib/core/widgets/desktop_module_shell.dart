import 'package:flutter/material.dart';

class DesktopModuleShell extends StatelessWidget {
  const DesktopModuleShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    required this.onBack,
    this.actions = const [],
    this.embedded = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget body;
  final VoidCallback onBack;
  final List<Widget> actions;
  final bool embedded;

  static const navy = Color(0xFF09213C);
  static const ink = Color(0xFF10243E);
  static const muted = Color(0xFF64748B);
  static const teal = Color(0xFF0F766E);
  static const canvas = Color(0xFFF3F7F7);
  static const line = Color(0xFFE1EAE8);

  @override
  Widget build(BuildContext context) {
    final moduleContent = Column(
      children: [
        Container(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B665E), Color(0xFF149674)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: teal, size: 27),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );

    if (embedded) {
      return ColoredBox(color: canvas, child: moduleContent);
    }

    return Scaffold(
      backgroundColor: canvas,
      body: Row(
        children: [
          Container(
            width: 224,
            color: navy,
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(19, 24, 16, 24),
                    child: Row(
                      children: [
                        Icon(Icons.local_hospital_rounded,
                            color: Colors.white, size: 30),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'PRIVATE\nPRACTICES',
                            style: TextStyle(
                              color: Colors.white,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _sideItem(
                          icon: Icons.dashboard_rounded,
                          label: 'Dashboard',
                          onTap: onBack,
                        ),
                        const SizedBox(height: 6),
                        _sideItem(
                          icon: icon,
                          label: title,
                          selected: true,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: Color(0xFF75D9C2), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Secure clinical workspace',
                            style: TextStyle(
                                color: Color(0xFF9FB2C5), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: moduleContent),
        ],
      ),
    );
  }

  Widget _sideItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    return Material(
      color: selected ? teal : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : const Color(0xFFB8C7D7),
                  size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFFD8E2EC),
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopPanel extends StatelessWidget {
  const DesktopPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesktopModuleShell.line),
        boxShadow: [
          BoxShadow(
            color: DesktopModuleShell.navy.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}
