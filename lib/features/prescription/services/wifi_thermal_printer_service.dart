import 'dart:convert';
import 'dart:io';

class WifiThermalPrinterService {
  Future<void> printText({
    required String printerIp,
    int port = 9100,
    required String text,
  }) async {
    final socket = await Socket.connect(
      printerIp,
      port,
      timeout: const Duration(seconds: 5),
    );

    try {
      final bytes = <int>[];

      bytes.addAll([0x1B, 0x40]);
      bytes.addAll(utf8.encode(text));
      bytes.addAll([0x0A, 0x0A, 0x0A]);
      bytes.addAll([0x1D, 0x56, 0x00]);

      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}
