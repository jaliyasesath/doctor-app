import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PrescriptionPdfHelper {
  static Future<File> generatePdf({
    required String medicalCenterName,
    required String doctorName,
    required String specialization,
    required String clinicAddress,
    required String rxNo,
    required String date,
    required String patientName,
    required String patientAge,
    required String patientGender,
    required List<Map<String, String>> items,
    required String qrValue,

    // Doctor Stamp Fields
    String qualifications = '',
    String profession = '',
    String slmcRegNo = '',
    String affiliation = '',
    String contactNumber = '',
    String signaturePath = '',
  }) async {
    final pdf = pw.Document();

    pw.Widget signatureWidget() {
      if (signaturePath.isEmpty) return pw.SizedBox();

      final file = File(signaturePath);
      if (!file.existsSync()) return pw.SizedBox();

      return pw.Column(
        children: [
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(file.readAsBytesSync()),
              height: 60,
            ),
          ),
          pw.SizedBox(height: 6),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  medicalCenterName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text('Dr. $doctorName'),
                if (specialization.isNotEmpty) pw.Text(specialization),
                if (clinicAddress.isNotEmpty)
                  pw.Text(
                    clinicAddress,
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),
          pw.Divider(),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: $date'),
              pw.Text('Rx: $rxNo'),
            ],
          ),

          pw.SizedBox(height: 8),

          pw.Text(
            'Patient Details',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Name: $patientName'),
          pw.Text('Age: $patientAge'),
          pw.Text('Gender: $patientGender'),

          pw.SizedBox(height: 8),
          pw.Divider(),

          pw.Center(
            child: pw.Text(
              'Prescription',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Divider(),

          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$index. ${item['medicineName'] ?? ''}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${item['dosage'] ?? ''} • ${item['frequency'] ?? ''} • ${item['duration'] ?? ''}',
                  ),
                  if ((item['instructions'] ?? '').isNotEmpty)
                    pw.Text(item['instructions'] ?? ''),
                ],
              ),
            );
          }),

          pw.Divider(),

          // Doctor Signature + Stamp
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                signatureWidget(),

                pw.Text(
                  'Dr. $doctorName',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),

                if (qualifications.isNotEmpty) pw.Text(qualifications),

                if (profession.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(profession),
                ],

                if (slmcRegNo.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('SLMC Reg. No: $slmcRegNo'),
                ],

                if (affiliation.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(affiliation),
                ],

                if (contactNumber.isNotEmpty)
                  pw.Text('Tel: $contactNumber'),
              ],
            ),
          ),

          pw.Divider(),

          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Prescription QR',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrValue,
                  width: 100,
                  height: 100,
                ),
                pw.SizedBox(height: 6),
                pw.Text(qrValue),
              ],
            ),
          ),

          pw.SizedBox(height: 10),
          pw.Divider(),

          pw.Center(
            child: pw.Text(
              'GET WELL SOON',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeRxNo = rxNo.replaceAll('/', '_').replaceAll('\\', '_');
    final file = File('${dir.path}/prescription_$safeRxNo.pdf');

    await file.writeAsBytes(await pdf.save());

    return file;
  }
}