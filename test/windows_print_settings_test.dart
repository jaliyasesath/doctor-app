import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/prescription/desktop/windows_print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('millimetres become PDF points and orientation changes page dimensions', () {
    const s=WindowsPrintSettings(paper:'A5',landscape:true,top:12,left:8);
    expect(s.valid,isTrue);
    expect(s.format.width,closeTo(PdfPageFormat.a5.height,.01));
    expect(s.format.marginTop,closeTo(12*PdfPageFormat.mm,.01));
    expect(s.format.marginLeft,closeTo(8*PdfPageFormat.mm,.01));
  });
  test('invalid margins and unsupported paper sizes are rejected', () {
    expect(const WindowsPrintSettings(top:-1).valid,isFalse);
    expect(const WindowsPrintSettings(left:double.nan).valid,isFalse);
    expect(const WindowsPrintSettings(paper:'58mm').valid,isFalse);
    expect(const WindowsPrintSettings(paper:'A5',left:40,right:40).valid,isFalse);
  });
  test('prescription and bill defaults are separate and survive reload', () async {
    await const WindowsPrintSettings(paper:'A5',printerUrl:'printer-a').save(false);
    await const WindowsPrintSettings(paper:'A4',printerUrl:'printer-b').save(true);
    expect((await WindowsPrintSettings.load(false)).paper,'A5');
    expect((await WindowsPrintSettings.load(true)).printerUrl,'printer-b');
  });
  test('malformed saved settings safely fall back to defaults', () async {
    SharedPreferences.setMockInitialValues({'pp_windows_rx_print_v1':'invalid JSON'});
    expect((await WindowsPrintSettings.load(false)).paper,'A4');
  });
}
