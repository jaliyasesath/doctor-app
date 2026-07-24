import 'package:flutter/material.dart';

class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF5F8FC),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Color(0xFF0B6E99),
              ),
              SizedBox(height: 12),
              Text(
                'This section could not be displayed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF16324F),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Please reopen the page and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF587089),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
