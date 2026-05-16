import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../data/local/database_helper.dart';
import '../data/prescription_store.dart';
import '../models/prescription_item.dart';
import 'print_preview_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool _isScanned = false;

  List<PrescriptionItem> _parseItems(String itemsText) {
    final List<PrescriptionItem> parsedItems = [];

    final lines = itemsText.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(' | ');

      if (parts.length >= 5) {
        parsedItems.add(
          PrescriptionItem(
            medicineName: parts[0],
            dosage: parts[1],
            frequency: parts[2],
            duration: parts[3],
            instructions: parts[4],
          ),
        );
      }
    }

    return parsedItems;
  }

  Future<void> _handleScan(String code) async {
    if (_isScanned) return;
    _isScanned = true;

    try {
      final rxNo = code.replaceAll('RX-', '').trim();

      final data = await DatabaseHelper.instance.getPrescriptionByNo(rxNo);

      if (data == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription not found')),
        );

        Navigator.pop(context);
        return;
      }

      final parsedItems = _parseItems(data['items_text'] ?? '');

      PrescriptionStore.setPatientDetails(
        name: data['patient_name'] ?? '',
        age: data['patient_age'] ?? '',
        gender: data['patient_gender'] ?? '',
      );

      PrescriptionStore.setItems(parsedItems);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPreviewScreen(
            passedRxNo: data['prescription_no'],
            passedDate: data['prescription_date'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;

              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  _handleScan(code);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}