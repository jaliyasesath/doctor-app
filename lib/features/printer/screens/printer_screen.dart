import 'package:flutter/material.dart';

class PrinterScreen extends StatelessWidget {
  const PrinterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Bluetooth thermal printing is temporarily disabled for iOS testing.\n\nUse PDF preview / share / AirPrint for iPhone.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}