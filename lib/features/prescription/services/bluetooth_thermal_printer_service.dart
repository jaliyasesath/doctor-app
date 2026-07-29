import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prescription_item.dart';

class BluetoothThermalPrinterService {
  static const String _addressKey = 'bluetooth_printer_address';
  static const String _nameKey = 'bluetooth_printer_name';

  Future<List<BluetoothInfo>> pairedPrinters() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> get isBluetoothEnabled {
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  Future<bool> get hasPermission {
    return PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<bool> get isConnected {
    return PrintBluetoothThermal.connectionStatus;
  }

  Future<String?> get savedAddress async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_addressKey);
  }

  Future<String?> get savedName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  Future<void> savePrinter(BluetoothInfo printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, printer.macAdress);
    await prefs.setString(_nameKey, printer.name);
  }

  Future<bool> connect(BluetoothInfo printer) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (connected) {
      await PrintBluetoothThermal.disconnect;
    }

    final success = await PrintBluetoothThermal.connect(
      macPrinterAddress: printer.macAdress,
    );
    if (success) {
      await savePrinter(printer);
    }
    return success;
  }

  Future<bool> connectSaved() async {
    if (await PrintBluetoothThermal.connectionStatus) return true;
    final address = await savedAddress;
    if (address == null || address.trim().isEmpty) return false;
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  Future<bool> disconnect() {
    return PrintBluetoothThermal.disconnect;
  }

  Future<bool> printTest() async {
    if (!await connectSaved()) return false;
    final generator = await _generator();
    final bytes = <int>[]
      ..addAll(generator.reset())
      ..addAll(
        generator.text(
          'PRIVATE PRACTICE',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      )
      ..addAll(
        generator.text(
          'BT-58D printer connected',
          styles: const PosStyles(align: PosAlign.center),
        ),
      )
      ..addAll(generator.hr())
      ..addAll(
        generator.text(
          'Test print successful',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      )
      ..addAll(generator.feed(3));
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<bool> printDocument({
    required bool billMode,
    required String medicalCenterName,
    required String doctorName,
    required String specialization,
    required String clinicAddress,
    required String rxNo,
    required String date,
    required String patientName,
    required String patientAge,
    required String patientGender,
    required List<PrescriptionItem> items,
    required String qualifications,
    required String profession,
    required String slmcRegNo,
    required String affiliation,
    required String contactNumber,
    required double consultationFee,
    required String qrValue,
  }) async {
    if (!await connectSaved()) return false;

    final generator = await _generator();
    final bytes = <int>[]
      ..addAll(generator.reset())
      ..addAll(
        generator.text(
          _safe(medicalCenterName.toUpperCase()),
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      )
      ..addAll(
        generator.text(
          _safe('Dr. $doctorName'),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );

    if (specialization.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _safe(specialization),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (clinicAddress.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          _safe(clinicAddress),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    bytes
      ..addAll(generator.hr())
      ..addAll(
        generator.row([
          PosColumn(text: _safe('Rx: $rxNo'), width: 7),
          PosColumn(
            text: _safe(date),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      )
      ..addAll(generator.hr())
      ..addAll(generator.text(_safe('Patient: $patientName')))
      ..addAll(
        generator.text(
          _safe('Age: $patientAge   Gender: $patientGender'),
        ),
      )
      ..addAll(generator.hr())
      ..addAll(
        generator.text(
          billMode ? 'BILL RECEIPT' : 'PRESCRIPTION',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      )
      ..addAll(generator.hr());

    if (items.isEmpty) {
      bytes.addAll(generator.text('No medicines added'));
    } else if (billMode) {
      final billItems = items.where((item) => !item.prescriptionOnly).toList();
      for (var index = 0; index < billItems.length; index++) {
        final item = billItems[index];
        bytes
          ..addAll(
            generator.text(
              _safe('${index + 1}. ${item.medicineName}'),
              styles: const PosStyles(bold: true),
            ),
          )
          ..addAll(
            generator.row([
              PosColumn(
                text: _safe('Qty ${_quantity(item.quantity)}'),
                width: 6,
              ),
              PosColumn(
                text: 'Rs.${item.lineTotal.toStringAsFixed(2)}',
                width: 6,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]),
          );
      }

      final medicineTotal = billItems.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );
      final grandTotal = consultationFee + medicineTotal;
      bytes
        ..addAll(generator.hr())
        ..addAll(_moneyRow(generator, 'Channeling Fee', consultationFee))
        ..addAll(_moneyRow(generator, 'Medicine Charges', medicineTotal))
        ..addAll(generator.hr())
        ..addAll(
          generator.row([
            PosColumn(
              text: 'GRAND TOTAL',
              width: 6,
              styles: const PosStyles(bold: true),
            ),
            PosColumn(
              text: 'Rs.${grandTotal.toStringAsFixed(2)}',
              width: 6,
              styles: const PosStyles(align: PosAlign.right, bold: true),
            ),
          ]),
        )
        ..addAll(
          generator.text(
            'PAID - CASH',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          ),
        );
    } else {
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        bytes.addAll(
          generator.text(
            _safe('${index + 1}. ${item.medicineName}'),
            styles: const PosStyles(bold: true),
          ),
        );
        final schedule = [
          item.dosage,
          item.frequency,
          item.duration,
        ].where((value) => value.trim().isNotEmpty).join(' | ');
        if (schedule.isNotEmpty) {
          bytes.addAll(generator.text(_safe(schedule)));
        }
        if (item.instructions.trim().isNotEmpty) {
          bytes.addAll(
            generator.text(_safe('Note: ${item.instructions}')),
          );
        }
        bytes.addAll(generator.feed(1));
      }
    }

    bytes.addAll(generator.hr());
    for (final line in [
      'Dr. $doctorName',
      qualifications,
      profession,
      slmcRegNo.trim().isEmpty ? '' : 'SLMC Reg. No: $slmcRegNo',
      affiliation,
      contactNumber.trim().isEmpty ? '' : 'Tel: $contactNumber',
    ]) {
      if (line.trim().isNotEmpty) {
        bytes.addAll(generator.text(_safe(line)));
      }
    }

    if (qrValue.trim().isNotEmpty) {
      bytes
        ..addAll(generator.feed(1))
        ..addAll(generator.qrcode(_safe(qrValue)));
    }

    bytes
      ..addAll(
        generator.text(
          billMode ? 'Thank you' : 'Get well soon',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      )
      ..addAll(generator.feed(4));

    return PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<Generator> _generator() async {
    final profile = await CapabilityProfile.load();
    return Generator(PaperSize.mm58, profile);
  }

  List<int> _moneyRow(Generator generator, String label, double amount) {
    return generator.row([
      PosColumn(text: label, width: 7),
      PosColumn(
        text: 'Rs.${amount.toStringAsFixed(2)}',
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  String _quantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String _safe(String value) {
    return value
        .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
