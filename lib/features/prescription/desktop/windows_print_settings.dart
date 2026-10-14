import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowsPrintSettings {
  const WindowsPrintSettings({this.printerUrl = '', this.paper = 'A4',
    this.landscape = false, this.top = 10, this.bottom = 10, this.left = 10, this.right = 10});
  final String printerUrl;
  final String paper;
  final bool landscape;
  final double top, bottom, left, right;
  PdfPageFormat get format {
    final base = paper == 'A5' ? PdfPageFormat.a5 : PdfPageFormat.a4;
    final size = landscape ? base.landscape : base;
    return PdfPageFormat(size.width, size.height, marginTop: top * PdfPageFormat.mm,
      marginBottom: bottom * PdfPageFormat.mm, marginLeft: left * PdfPageFormat.mm,
      marginRight: right * PdfPageFormat.mm);
  }
  bool get valid => ['A4','A5'].contains(paper) &&
    [top,bottom,left,right].every((v) => v.isFinite && v >= 0 && v <= 40) &&
    format.availableWidth >= 70 * PdfPageFormat.mm && format.availableHeight >= 80 * PdfPageFormat.mm;
  Map<String, Object> toJson() => {'printerUrl':printerUrl, 'paper':paper,
    'landscape':landscape,'top':top,'bottom':bottom,'left':left,'right':right};
  static Future<WindowsPrintSettings> load(bool bill) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(bill ? 'pp_windows_bill_print_v1' : 'pp_windows_rx_print_v1');
    if (value == null) return const WindowsPrintSettings();
    try {
      final m = jsonDecode(value) as Map<String,dynamic>;
      double number(String key) => (m[key] as num?)?.toDouble() ?? 10;
      final result = WindowsPrintSettings(printerUrl:m['printerUrl'] as String? ?? '',
        paper:m['paper'] as String? ?? 'A4',landscape:m['landscape'] as bool? ?? false,
        top:number('top'),bottom:number('bottom'),left:number('left'),right:number('right'));
      return result.valid ? result : const WindowsPrintSettings();
    } catch (_) { return const WindowsPrintSettings(); }
  }
  Future<void> save(bool bill) async {
    if (!valid) throw ArgumentError('Invalid paper margins.');
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(bill ? 'pp_windows_bill_print_v1' : 'pp_windows_rx_print_v1', jsonEncode(toJson()));
    if (!saved) throw StateError('Printer settings could not be saved.');
  }
}
