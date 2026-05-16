import 'dart:io';

//import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/data/doctor_session.dart';
import '../data/prescription_store.dart';
import '../utils/prescription_pdf_helper.dart';

class PrintPreviewScreen extends StatefulWidget {
  final String? passedRxNo;
  final String? passedDate;

  const PrintPreviewScreen({
    super.key,
    this.passedRxNo,
    this.passedDate,
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  //final BlueThermalPrinter printer = BlueThermalPrinter.instance;

  // bool _isTryingAutoConnect = true;
  // bool _isPrinterConnected = false;
  bool _isLoadingRx = true;
  bool _isLoadingDoctor = true;
  bool _isSharingPdf = false;
  bool _isSharingWhatsApp = false;

  //String? _savedPrinterAddress;

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

      await _autoConnectPrinter();
    } else {
      await _loadPersistentRx();
      await _autoConnectPrinter();
    }
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

  Future<void> _autoConnectPrinter() async {
  // Bluetooth printer disabled temporarily for iOS testing
  return;
}

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

  Future<void> _sharePdf() async {
    if (_isLoadingRx || _isLoadingDoctor || rxNo.isEmpty || qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, document is loading')),
      );
      return;
    }

    setState(() => _isSharingPdf = true);

    try {
      final File pdfFile = await _generateCurrentPdf();

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Prescription $rxNo',
        subject: 'Prescription $rxNo',
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
      final File pdfFile = await _generateCurrentPdf();

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
  //   final items = PrescriptionStore.items;
  //   final currentDate =
  //       widget.passedDate ?? DateTime.now().toString().substring(0, 10);

  //   try {
  //     if (_isLoadingRx || rxNo.isEmpty || qrValue.isEmpty) {
  //       if (!mounted) return;

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('RX number is still loading')),
  //       );
  //       return;
  //     }

  //     final isConnected = await printer.isConnected ?? false;

  //     if (!isConnected) {
  //       if (!mounted) return;

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Please connect printer first')),
  //       );
  //       return;
  //     }

  //     printer.printCustom(medicalCenterName.toUpperCase(), 2, 1);
  //     printer.printCustom('Dr. $doctorName', 1, 1);

  //     if (specialization.isNotEmpty) {
  //       printer.printCustom(specialization, 0, 1);
  //     }

  //     if (clinicAddress.isNotEmpty) {
  //       printer.printCustom(clinicAddress, 0, 1);
  //     }

  //     printer.printNewLine();
  //     printer.printCustom('--------------------------------', 0, 1);

  //     printer.printCustom('Date: $currentDate', 0, 0);
  //     printer.printCustom('Rx: $rxNo', 0, 2);
  //     printer.printCustom('--------------------------------', 0, 1);

  //     printer.printCustom('PATIENT DETAILS', 1, 0);

  //     if (PrescriptionStore.patientName.isNotEmpty) {
  //       printer.printCustom('Name: ${PrescriptionStore.patientName}', 0, 0);
  //     }
  //     if (PrescriptionStore.patientAge.isNotEmpty) {
  //       printer.printCustom('Age: ${PrescriptionStore.patientAge}', 0, 0);
  //     }
  //     if (PrescriptionStore.patientGender.isNotEmpty) {
  //       printer.printCustom('Gender: ${PrescriptionStore.patientGender}', 0, 0);
  //     }

  //     printer.printCustom('--------------------------------', 0, 1);
  //     printer.printCustom('PRESCRIPTION', 1, 1);
  //     printer.printCustom('--------------------------------', 0, 1);

  //     int index = 1;
  //     for (final item in items) {
  //       printer.printCustom('$index. ${item.medicineName}', 1, 0);
  //       printer.printCustom(
  //         '${item.dosage} • ${item.frequency} • ${item.duration}',
  //         0,
  //         0,
  //       );

  //       if (item.instructions.isNotEmpty) {
  //         printer.printCustom(item.instructions, 0, 0);
  //       }

  //       printer.printNewLine();
  //       index++;
  //     }

  //     printer.printCustom('--------------------------------', 0, 1);

  //     // Thermal printers may not support signature image reliably,
  //     // so text stamp remains the stable output.
  //     printer.printCustom('Dr. $doctorName', 1, 1);

  //     if (qualifications.isNotEmpty) {
  //       printer.printCustom(qualifications, 0, 1);
  //     }

  //     if (profession.isNotEmpty) {
  //       printer.printCustom(profession, 0, 1);
  //     }

  //     if (slmcRegNo.isNotEmpty) {
  //       printer.printCustom('SLMC Reg. No: $slmcRegNo', 0, 1);
  //     }

  //     if (affiliation.isNotEmpty) {
  //       printer.printCustom(affiliation, 0, 1);
  //     }

  //     if (contactNumber.isNotEmpty) {
  //       printer.printCustom('Tel: $contactNumber', 0, 1);
  //     }

  //     printer.printCustom('--------------------------------', 0, 1);

  //     printer.printCustom('Prescription QR', 1, 1);
  //     await printer.printQRcode(qrValue, 220, 220, 1);
  //     printer.printCustom(qrValue, 0, 1);
  //     printer.printCustom('--------------------------------', 0, 1);
  //     printer.printCustom('GET WELL SOON', 1, 1);
  //     printer.printCustom('--------------------------------', 0, 1);

  //     printer.printNewLine();
  //     printer.printNewLine();

  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Print sent with QR ($rxNo)')),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Print failed: $e')),
  //     );
  //   }
  // }

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

        const SizedBox(height: 6),

        if (profession.isNotEmpty)
          Text(
            profession,
            style: const TextStyle(fontSize: 11),
          ),

        const SizedBox(height: 6),

        if (slmcRegNo.isNotEmpty)
          Text(
            'SLMC Reg. No: $slmcRegNo',
            style: const TextStyle(fontSize: 11),
          ),

        const SizedBox(height: 6),

        if (affiliation.isNotEmpty)
          Text(
            affiliation,
            style: const TextStyle(fontSize: 11),
          ),

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
      ),
      body: isLoading
    ? const Center(child: CircularProgressIndicator())
    : Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: const Center(
          child: Text(
            'Bluetooth print disabled for iOS testing.\n\nUse PDF / WhatsApp sharing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  icon: _isSharingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share),
                  label: Text(_isSharingPdf ? 'PDF...' : 'PDF'),
                  onPressed: _isSharingPdf ? null : _sharePdf,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
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
                  label: Text(_isSharingWhatsApp ? 'Wait...' : 'WhatsApp'),
                  onPressed: _isSharingWhatsApp ? null : _shareWhatsApp,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  onPressed: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}