import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Desktop-only PDF composition. No temporary patient files are written.
class WindowsDocumentPdf {
  static Future<Uint8List> build({required PdfPageFormat format,
    required Map<String,String> header, required List<Map<String,String>> items,
    required bool bill, required Map<String,double> totals,
    Uint8List? logo, Uint8List? signature}) async {
    final doc = pw.Document();
    String h(String key) => header[key] ?? '';
    String money(double value) => 'Rs. ${value.toStringAsFixed(2)}';
    final billItems = items.where((i) => i['prescriptionOnly'] != 'true').toList();
    final display = bill ? billItems : items;
    doc.addPage(pw.MultiPage(pageFormat:format,
      margin:pw.EdgeInsets.fromLTRB(format.marginLeft,format.marginTop,format.marginRight,format.marginBottom),
      maxPages:100,
      footer:(context) => pw.Align(alignment:pw.Alignment.centerRight,
        child:pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',style:const pw.TextStyle(fontSize:9))),
      build:(context) => [
        if (logo != null && logo.isNotEmpty) pw.Center(child:pw.Image(pw.MemoryImage(logo),height:45)),
        pw.Center(child:pw.Text(h('center'),style:pw.TextStyle(fontSize:17,fontWeight:pw.FontWeight.bold))),
        pw.Center(child:pw.Text('Dr. ${h('doctor')}')),
        if (h('specialization').isNotEmpty) pw.Center(child:pw.Text(h('specialization'))),
        if (h('address').isNotEmpty) pw.Center(child:pw.Text(h('address'),textAlign:pw.TextAlign.center)),
        pw.Divider(),
        pw.Text('${bill ? 'Bill' : 'Prescription'}: ${h('rx')}    Date: ${h('date')}',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:8),
        pw.Text('Patient: ${h('patient')}'),
        pw.Text('Age: ${h('age')}    Gender: ${h('gender')}'),
        pw.Divider(),
        if (display.isEmpty) pw.Text(bill ? 'No chargeable medicine items.' : 'No medicine items.'),
        for (var index=0;index<display.length;index++)
          pw.Padding(padding:const pw.EdgeInsets.only(bottom:10),child:pw.Column(
            crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
              pw.Text('${index+1}. ${display[index]['medicineName'] ?? ''}',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
              if (!bill) ...[
                pw.Text('${display[index]['dosage'] ?? ''} / ${display[index]['frequency'] ?? ''} / ${display[index]['duration'] ?? ''}'),
                if ((display[index]['instructions'] ?? '').isNotEmpty) pw.Text(display[index]['instructions']!),
              ] else pw.Text('Qty: ${display[index]['quantity']}  Unit: ${display[index]['unitPrice']}  Total: ${display[index]['lineTotal']}'),
            ])),
        if (bill) ...[
          pw.Divider(),
          for (final key in ['Consultation','Medicines','Other charges','Discount','Total','Paid','Balance'])
            pw.Padding(padding:const pw.EdgeInsets.only(bottom:5),child:pw.Row(children:[
              pw.Expanded(child:pw.Text(key)),pw.Text(money(totals[key] ?? 0))])),
          if (h('saved').isNotEmpty) pw.Text(h('saved'),style:const pw.TextStyle(fontSize:9)),
        ] else ...[
          pw.Divider(),
          if (signature != null && signature.isNotEmpty) pw.Image(pw.MemoryImage(signature),height:45),
          for (final key in ['qualifications','profession','slmc','affiliation','contact'])
            if (h(key).isNotEmpty) pw.Text(h(key)),
          pw.SizedBox(height:8),
          if (h('qr').isNotEmpty) pw.BarcodeWidget(barcode:pw.Barcode.qrCode(),data:h('qr'),width:65,height:65),
          pw.Text('GET WELL SOON',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
        ],
      ]));
    return doc.save();
  }
}
