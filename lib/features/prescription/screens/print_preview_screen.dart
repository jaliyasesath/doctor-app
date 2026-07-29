import 'dart:async';
import 'dart:io';

//import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/data/doctor_session.dart';
import '../data/prescription_store.dart';
import '../services/bluetooth_thermal_printer_service.dart';
import '../services/wifi_thermal_printer_service.dart';
import '../utils/prescription_pdf_helper.dart';
import 'printer_settings_screen.dart';
import '../../../data/local/database_helper.dart';
import '../../sync/services/auto_sync_service.dart';

class PrintPreviewScreen extends StatefulWidget {
  final String? passedRxNo;
  final String? passedDate;
  final bool allowBillSave;

  const PrintPreviewScreen({
    super.key,
    this.passedRxNo,
    this.passedDate,
    this.allowBillSave = false,
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  final WifiThermalPrinterService _wifiPrinter = WifiThermalPrinterService();
  final BluetoothThermalPrinterService _bluetoothPrinter =
      BluetoothThermalPrinterService();

  bool _isLoadingRx = true;
  bool _isLoadingDoctor = true;
  bool _isSharingPdf = false;
  bool _isSharingWhatsApp = false;
  bool _isPrinting = false;
  bool _isBillMode = false;
  bool _alreadyBilled = false;

  String rxNo = '';
  String qrValue = '';

  String medicalCenterName = 'Doctor App Clinic';
  String doctorName = 'Doctor';
  String specialization = '';
  String clinicAddress = '';

  String qualifications = '';
  String profession = '';
  String slmcRegNo = '';
  String affiliation = '';
  String contactNumber = '';
  String signaturePath = '';

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadDoctorHeader();

    if (widget.passedRxNo != null && widget.passedDate != null) {
      rxNo = widget.passedRxNo!;
      qrValue = 'RX-$rxNo';
      if (mounted) setState(() => _isLoadingRx = false);
    } else {
      await _loadPersistentRx();
    }
    await _checkAlreadyBilled();

    //await _autoConnectPrinter();
  }

  Future<void> _loadDoctorHeader() async {
    final center = await DoctorSession.getMedicalCenterName();
    final doctor = await DoctorSession.getDoctorName();
    final spec = await DoctorSession.getSpecialization();
    final address = await DoctorSession.getClinicAddress();
    final stamp = await DoctorSession.getDoctorStamp();

    if (!mounted) return;

    setState(() {
      medicalCenterName = center.isNotEmpty ? center : 'Doctor App Clinic';
      doctorName = doctor.isNotEmpty ? doctor : 'Doctor';
      specialization = spec;
      clinicAddress = address;

      qualifications = stamp['qualifications']?.toString() ?? '';
      profession = stamp['profession']?.toString() ?? '';
      slmcRegNo = stamp['slmc_reg_no']?.toString() ?? '';
      affiliation = stamp['affiliation']?.toString() ?? '';
      contactNumber = stamp['contact_number']?.toString() ?? '';
      signaturePath = stamp['signature_path']?.toString() ?? '';

      _isLoadingDoctor = false;
    });
  }

  Future<void> _loadPersistentRx() async {
    final generatedRx = await PrescriptionStore.generatePersistentRxNumber();

    if (!mounted) return;

    setState(() {
      rxNo = generatedRx;
      qrValue = 'RX-$generatedRx';
      _isLoadingRx = false;
    });
  }

  Future<void> _checkAlreadyBilled() async {
    final prescription =
        await DatabaseHelper.instance.getPrescriptionByNo(rxNo);

    final prescriptionId = prescription?['id'] as int?;

    if (prescriptionId == null) return;

    final bill =
        await DatabaseHelper.instance.getBillByPrescription(prescriptionId);

    if (!mounted) return;

    setState(() {
      _alreadyBilled = bill != null;
    });
  }

  // Future<void> _autoConnectPrinter() async {
  //   if (!Platform.isAndroid) return;

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final savedAddress = prefs.getString('bluetooth_printer_address');

  //     if (savedAddress == null || savedAddress.isEmpty) return;

  //     final devices = await printer.getBondedDevices();

  //     BluetoothDevice? selected;

  //     for (final d in devices) {
  //       if (d.address == savedAddress) {
  //         selected = d;
  //         break;
  //       }
  //     }

  //     if (selected != null) {
  //       await printer.connect(selected);
  //     }
  //   } catch (_) {}
  // }

  List<Map<String, String>> _getPdfItems() {
    return PrescriptionStore.items.map((item) {
      return {
        'medicineName': item.medicineName,
        'dosage': item.dosage,
        'frequency': item.frequency,
        'duration': item.duration,
        'instructions': item.instructions,
      };
    }).toList();
  }

  Future<File> _generateCurrentPdf() async {
    final currentDate =
        widget.passedDate ?? DateTime.now().toString().substring(0, 10);

    return PrescriptionPdfHelper.generatePdf(
      medicalCenterName: medicalCenterName,
      doctorName: doctorName,
      specialization: specialization,
      clinicAddress: clinicAddress,
      rxNo: rxNo,
      date: currentDate,
      patientName: PrescriptionStore.patientName,
      patientAge: PrescriptionStore.patientAge,
      patientGender: PrescriptionStore.patientGender,
      items: _getPdfItems(),
      qrValue: qrValue,
      qualifications: qualifications,
      profession: profession,
      slmcRegNo: slmcRegNo,
      affiliation: affiliation,
      contactNumber: contactNumber,
      signaturePath: signaturePath,
    );
  }

  Rect _sharePositionOrigin() {
    final renderObject = context.findRenderObject();

    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.width > 0 &&
        renderObject.size.height > 0) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }

    final screenSize = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _sharePdf() async {
    if (_isLoadingRx || _isLoadingDoctor || rxNo.isEmpty || qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, document is loading')),
      );
      return;
    }

    setState(() => _isSharingPdf = true);

    try {
      final pdfFile = await _generateCurrentPdf();

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Prescription $rxNo',
        subject: 'Prescription $rxNo',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF share failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSharingPdf = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    if (_isLoadingRx || _isLoadingDoctor || rxNo.isEmpty || qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, document is loading')),
      );
      return;
    }

    setState(() => _isSharingWhatsApp = true);

    try {
      final pdfFile = await _generateCurrentPdf();

      final message = Uri.encodeComponent(
        'Dear ${PrescriptionStore.patientName},\n'
        'Your prescription is ready.\n'
        'Rx No: $rxNo\n'
        'Get well soon.\n'
        '- Dr. $doctorName',
      );

      final whatsappUrl = Uri.parse('whatsapp://send?text=$message');
      final fallbackUrl = Uri.parse('https://wa.me/?text=$message');

      final opened = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        await launchUrl(
          fallbackUrl,
          mode: LaunchMode.externalApplication,
        );
      }

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Prescription $rxNo',
        subject: 'Prescription $rxNo',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp share failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSharingWhatsApp = false);
    }
  }

  // Future<void> _printNow() async {
  // if (_isLoadingRx || _isLoadingDoctor || rxNo.isEmpty || qrValue.isEmpty) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Please wait, document is loading')),
  //   );
  //   return;
  // }

  Future<void> _printNow() async {
    if (_isLoadingRx || _isLoadingDoctor || rxNo.isEmpty || qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, document is loading')),
      );
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final currentDate =
          widget.passedDate ?? DateTime.now().toString().substring(0, 10);

      final printed = await _bluetoothPrinter.printDocument(
        billMode: _isBillMode,
        medicalCenterName: medicalCenterName,
        doctorName: doctorName,
        specialization: specialization,
        clinicAddress: clinicAddress,
        rxNo: rxNo,
        date: currentDate,
        patientName: PrescriptionStore.patientName,
        patientAge: PrescriptionStore.patientAge,
        patientGender: PrescriptionStore.patientGender,
        items: PrescriptionStore.items,
        qualifications: qualifications,
        profession: profession,
        slmcRegNo: slmcRegNo,
        affiliation: affiliation,
        contactNumber: contactNumber,
        consultationFee: PrescriptionStore.consultationFee,
        qrValue: qrValue,
      );

      if (!mounted) return;
      if (printed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isBillMode
                  ? 'Bill sent to BT-58D printer.'
                  : 'Prescription sent to BT-58D printer.',
            ),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      } else {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Printer not connected'),
            content: const Text(
              'Pair BT-58D in the phone Bluetooth settings, then connect it in Thermal Printer settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Printer Settings'),
              ),
            ],
          ),
        );
        if (openSettings == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PrinterSettingsScreen(),
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thermal print failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // Future<void> _printNow() async {
  //   if (_isLoadingRx || _isLoadingDoctor || rxNo.isEmpty || qrValue.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please wait, document is loading')),
  //     );
  //     return;
  //   }

  //   if (Platform.isIOS) {
  //     await _printWifiIos();
  //   } else if (Platform.isAndroid) {
  //     await _printBluetoothAndroid();
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Printing is not supported on this device')),
  //     );
  //   }
  // }

  Future<void> _printWifiIos() async {
    final prefs = await SharedPreferences.getInstance();
    final printerIp = prefs.getString('wifi_printer_ip') ?? '';

    if (printerIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please set WiFi printer IP address first')),
      );
      return;
    }

    final currentDate =
        widget.passedDate ?? DateTime.now().toString().substring(0, 10);

    final text = '''
${medicalCenterName.toUpperCase()}
Dr. $doctorName
$specialization
$clinicAddress

-----------------------------
Date: $currentDate
Rx: $rxNo
-----------------------------

PATIENT DETAILS
Name: ${PrescriptionStore.patientName}
Age: ${PrescriptionStore.patientAge}
Gender: ${PrescriptionStore.patientGender}

-----------------------------
PRESCRIPTION
-----------------------------
${PrescriptionStore.items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      return '$index. ${item.medicineName}\n${item.dosage} | ${item.frequency} | ${item.duration}\n${item.instructions}';
    }).join('\n\n')}

-----------------------------
Dr. $doctorName
$qualifications
$profession
SLMC Reg. No: $slmcRegNo
$affiliation
Tel: $contactNumber
-----------------------------
QR: $qrValue

GET WELL SOON
-----------------------------
''';

    try {
      await _wifiPrinter.printText(
        printerIp: printerIp,
        text: text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi print sent ($rxNo)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi print failed: $e')),
      );
    }
  }

// Future<void> _printBluetoothAndroid() async {
//   ScaffoldMessenger.of(context).showSnackBar(
//     const SnackBar(
//       content: Text('Android Bluetooth print temporarily disabled'),
//     ),
//   );
// }

  Future<void> _saveBillIfNeeded() async {
    if (!widget.allowBillSave) {
      return;
    }
    final billItems =
        PrescriptionStore.items.where((e) => !e.prescriptionOnly).toList();

    final consultationFee = PrescriptionStore.consultationFee;

    final medicineTotal = billItems.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    final grandTotal = consultationFee + medicineTotal;

    final existingPrescription =
        await DatabaseHelper.instance.getPrescriptionByNo(rxNo);

    final existingPrescriptionId = existingPrescription?['id'] as int?;

    bool shouldSaveBill = true;

    if (existingPrescriptionId != null) {
      final existingBill = await DatabaseHelper.instance.getBillByPrescription(
        existingPrescriptionId,
      );

      if (existingBill != null) {
        shouldSaveBill = false;
      }
    }

    final currentDoctorId = await DoctorSession.getDoctorId();

    if (shouldSaveBill) {
      await DatabaseHelper.instance.insertPrescriptionBill({
        'doctor_id': existingPrescription?['doctor_id'] ?? currentDoctorId,
        'patient_id': existingPrescription?['patient_id'],
        'prescription_id': existingPrescriptionId,
        'prescription_no': rxNo,
        'consultation_fee': consultationFee,
        'medicine_charges': medicineTotal,
        'other_charges': 0,
        'discount_amount': 0,
        'total_amount': grandTotal,
        'paid_amount': grandTotal,
        'balance_amount': 0,
        'payment_method': 'Cash',
        'payment_status': 'Paid',
        'notes': 'Bill generated from preview',
      });
      unawaited(AutoSyncService.syncPendingChanges());
    }
  }

  bool _hasValidSignature() {
    return signaturePath.isNotEmpty && File(signaturePath).existsSync();
  }

  Widget _doctorStampPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        if (_hasValidSignature())
          Center(
            child: Image.file(
              File(signaturePath),
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
        if (_hasValidSignature()) const SizedBox(height: 8),
        Text(
          'Dr. $doctorName',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        if (qualifications.isNotEmpty)
          Text(
            qualifications,
            style: const TextStyle(fontSize: 11),
          ),
        if (profession.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            profession,
            style: const TextStyle(fontSize: 11),
          ),
        ],
        if (slmcRegNo.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'SLMC Reg. No: $slmcRegNo',
            style: const TextStyle(fontSize: 11),
          ),
        ],
        if (affiliation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            affiliation,
            style: const TextStyle(fontSize: 11),
          ),
        ],
        if (contactNumber.isNotEmpty)
          Text(
            'Tel: $contactNumber',
            style: const TextStyle(fontSize: 11),
          ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = PrescriptionStore.items;
    final currentDate =
        widget.passedDate ?? DateTime.now().toString().substring(0, 10);

    final isLoading = _isLoadingRx || _isLoadingDoctor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            medicalCenterName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Dr. $doctorName'),
                          if (specialization.isNotEmpty) Text(specialization),
                          if (clinicAddress.isNotEmpty) Text(clinicAddress),
                        ],
                      ),
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rx No: $rxNo'),
                        Text('Date: $currentDate'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Patient: ${PrescriptionStore.patientName}'),
                    Text('Age: ${PrescriptionStore.patientAge}'),
                    Text('Gender: ${PrescriptionStore.patientGender}'),
                    const Divider(height: 30),
                    Row(
                      children: [
                        Text(
                          _isBillMode ? 'Bill Receipt' : 'Prescription',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isBillMode && _alreadyBilled) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Already Billed ✅',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text('No medicines added')
                    else
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$index. ${item.medicineName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.dosage} • ${item.frequency} • ${item.duration}',
                              ),
                              if (item.instructions.isNotEmpty && !_isBillMode)
                                Text(
                                  'Instructions: ${item.instructions}',
                                ),
                              if (_isBillMode && !item.prescriptionOnly) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Qty: ${item.quantity}',
                                    ),
                                    Text(
                                      'Rs. ${item.lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    if (_isBillMode) ...[
                      const Divider(height: 30),
                      Builder(
                        builder: (_) {
                          final medicineTotal = items
                              .where((e) => !e.prescriptionOnly)
                              .fold<double>(
                                0,
                                (sum, item) => sum + item.lineTotal,
                              );

                          final consultationFee =
                              PrescriptionStore.consultationFee;

                          final grandTotal = consultationFee + medicineTotal;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Channeling Fee'),
                                  Text(
                                    'Rs. ${consultationFee.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Medicine Charges'),
                                  Text(
                                    'Rs. ${medicineTotal.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Grand Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const Divider(height: 30),
                    _doctorStampPreview(),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          QrImageView(
                            data: qrValue,
                            size: 120,
                          ),
                          const SizedBox(height: 6),
                          Text(qrValue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFDCE9E5))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _isBillMode ? Icons.receipt_long : Icons.payments,
                        ),
                        label: Text(
                          _isBillMode ? 'Prescription View' : 'Bill View',
                          maxLines: 1,
                        ),
                        onPressed: () async {
                          setState(() => _isBillMode = !_isBillMode);

                          if (_isBillMode) {
                            final wasAlreadyBilled = _alreadyBilled;
                            await _saveBillIfNeeded();
                            await _checkAlreadyBilled();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  wasAlreadyBilled
                                      ? 'Bill already saved. Income report was not updated again.'
                                      : 'Bill saved successfully.',
                                ),
                                backgroundColor: wasAlreadyBilled
                                    ? Colors.orange
                                    : const Color(0xFF0F766E),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: _isSharingPdf
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _isSharingPdf ? 'Preparing...' : 'Share PDF',
                          maxLines: 1,
                        ),
                        onPressed: _isSharingPdf ? null : _sharePdf,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _isSharingWhatsApp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.chat),
                        label: Text(
                          _isSharingWhatsApp ? 'Preparing...' : 'WhatsApp',
                          maxLines: 1,
                        ),
                        onPressed: _isSharingWhatsApp ? null : _shareWhatsApp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print),
                        label: Text(
                          _isPrinting ? 'Printing...' : 'Print Now',
                          maxLines: 1,
                        ),
                        onPressed: _isPrinting ? null : _printNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E3B),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
