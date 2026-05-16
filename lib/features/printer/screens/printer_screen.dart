import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;

  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  String? savedPrinterAddress;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _loadDevices();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('printer_address');

    setState(() {
      savedPrinterAddress = address;
    });
  }

  Future<void> _loadDevices() async {
    final list = await printer.getBondedDevices();

    setState(() {
      devices = list;

      if (savedPrinterAddress != null) {
        for (final device in devices) {
          if (device.address == savedPrinterAddress) {
            selectedDevice = device;
            break;
          }
        }
      }
    });
  }

  Future<void> _connectPrinter() async {
    if (selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select printer first')),
      );
      return;
    }

    try {
      await printer.connect(selectedDevice!);

      final isConnected = await printer.isConnected ?? false;

      if (!mounted) return;

      if (isConnected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'printer_address',
          selectedDevice!.address ?? '',
        );

        setState(() {
          savedPrinterAddress = selectedDevice!.address;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer Connected & Saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection Failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    }
  }

  Future<void> _clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printer_address');

    if (!mounted) return;

    setState(() {
      savedPrinterAddress = null;
      selectedDevice = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved printer cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Printer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Devices',
            onPressed: _loadDevices,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Saved Printer',
            onPressed: _clearSavedPrinter,
          ),
        ],
      ),
      body: devices.isEmpty
          ? const Center(
              child: Text('No paired devices'),
            )
          : Column(
              children: [
                if (savedPrinterAddress != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Saved printer: $savedPrinterAddress',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isSelected = selectedDevice?.address == device.address;
                      final isSaved = savedPrinterAddress == device.address;

                      return ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(device.name ?? 'Unknown Printer'),
                        subtitle: Text(device.address ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSaved)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.bookmark,
                                  color: Colors.green,
                                ),
                              ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            selectedDevice = device;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _connectPrinter,
            child: const Text('Connect Printer'),
          ),
        ),
      ),
    );
  }
}