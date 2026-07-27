// import 'dart:io';

// import 'package:blue_thermal_printer/blue_thermal_printer.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class PrinterSettingsScreen extends StatefulWidget {
//   const PrinterSettingsScreen({super.key});

//   @override
//   State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
// }

// class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
//   final TextEditingController _ipController = TextEditingController();

//   final BlueThermalPrinter _bluetoothPrinter =
//       BlueThermalPrinter.instance;

//   List<BluetoothDevice> _devices = [];
//   BluetoothDevice? _selectedDevice;

//   bool _loadingDevices = false;
//   bool _isConnecting = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();

//     if (Platform.isAndroid) {
//       _loadBluetoothDevices();
//     }
//   }

//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();

//     _ipController.text = prefs.getString('wifi_printer_ip') ?? '';

//     final savedAddress =
//         prefs.getString('bluetooth_printer_address') ?? '';

//     if (savedAddress.isNotEmpty && _devices.isNotEmpty) {
//       _selectedDevice = _devices.firstWhere(
//         (d) => d.address == savedAddress,
//         orElse: () => _devices.first,
//       );
//     }

//     if (mounted) setState(() {});
//   }

//   Future<void> _loadBluetoothDevices() async {
//     setState(() => _loadingDevices = true);

//     try {
//       final devices = await _bluetoothPrinter.getBondedDevices();

//       if (!mounted) return;

//       setState(() {
//         _devices = devices;
//         _loadingDevices = false;
//       });

//       await _loadSettings();
//     } catch (e) {
//       if (!mounted) return;

//       setState(() => _loadingDevices = false);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Bluetooth devices load failed: $e')),
//       );
//     }
//   }

//   Future<void> _saveBluetoothPrinter() async {
//     if (_selectedDevice == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Select Bluetooth printer')),
//       );
//       return;
//     }

//     final prefs = await SharedPreferences.getInstance();

//     await prefs.setString(
//       'bluetooth_printer_address',
//       _selectedDevice!.address ?? '',
//     );

//     await prefs.setString(
//       'bluetooth_printer_name',
//       _selectedDevice!.name ?? 'Bluetooth Printer',
//     );

//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Bluetooth printer saved')),
//     );

//     Navigator.pop(context);
//   }

//   Future<void> _connectBluetoothPrinter() async {
//   if (_selectedDevice == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Select Bluetooth printer')),
//     );
//     return;
//   }

//   try {
//     setState(() => _isConnecting = true);

//     final isConnected =
//         await _bluetoothPrinter.isConnected ?? false;

//     if (!isConnected) {
//       await _bluetoothPrinter.connect(_selectedDevice!);
//     }

//     final prefs = await SharedPreferences.getInstance();

//     await prefs.setString(
//       'bluetooth_printer_address',
//       _selectedDevice!.address ?? '',
//     );

//     await prefs.setString(
//       'bluetooth_printer_name',
//       _selectedDevice!.name ?? 'Bluetooth Printer',
//     );

//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           'Connected: ${_selectedDevice!.name ?? 'Printer'}',
//         ),
//       ),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Connection failed: $e')),
//     );
//   } finally {
//     if (mounted) {
//       setState(() => _isConnecting = false);
//     }
//   }
// }

//   Future<void> _saveWifiPrinter() async {
//     final ip = _ipController.text.trim();

//     if (ip.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter WiFi printer IP address')),
//       );
//       return;
//     }

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('wifi_printer_ip', ip);

//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('WiFi printer IP saved')),
//     );

//     Navigator.pop(context);
//   }

//   @override
//   void dispose() {
//     _ipController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (Platform.isAndroid) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('Bluetooth Printer Settings'),
//         ),
//         body: Padding(
//           padding: const EdgeInsets.all(18),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Select paired Bluetooth thermal printer',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 12),

//               if (_loadingDevices)
//                 const Center(child: CircularProgressIndicator())
//               else if (_devices.isEmpty)
//                 const Text(
//                   'No paired Bluetooth printers found.\nPair printer from Android Bluetooth settings first.',
//                 )
//               else
//                 DropdownButtonFormField<BluetoothDevice>(
//                   value: _selectedDevice,
//                   decoration: const InputDecoration(
//                     border: OutlineInputBorder(),
//                     labelText: 'Bluetooth Printer',
//                   ),
//                   items: _devices.map((device) {
//                     return DropdownMenuItem(
//                       value: device,
//                       child: Text(
//                         '${device.name ?? 'Unknown'} (${device.address ?? ''})',
//                       ),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedDevice = value;
//                     });
//                   },
//                 ),

//               const SizedBox(height: 18),

//              SizedBox(
//   width: double.infinity,
//   height: 50,
//   child: ElevatedButton.icon(
//     onPressed: _isConnecting ? null : _connectBluetoothPrinter,
//     icon: _isConnecting
//         ? const SizedBox(
//             width: 18,
//             height: 18,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: Colors.white,
//             ),
//           )
//         : const Icon(Icons.bluetooth_connected),
//     label: Text(
//       _isConnecting ? 'Connecting...' : 'Connect Printer',
//     ),
//   ),
// ),

//               const SizedBox(height: 12),

//               SizedBox(
//                 width: double.infinity,
//                 height: 46,
//                 child: OutlinedButton.icon(
//                   onPressed: _loadBluetoothDevices,
//                   icon: const Icon(Icons.refresh),
//                   label: const Text('Refresh Printers'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('WiFi Printer Settings'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(18),
//         child: Column(
//           children: [
//             TextField(
//               controller: _ipController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(
//                 labelText: 'WiFi Printer IP Address',
//                 hintText: 'Example: 192.168.1.120',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 18),
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ElevatedButton.icon(
//                 onPressed: _saveWifiPrinter,
//                 icon: const Icon(Icons.save),
//                 label: const Text('Save WiFi Printer IP'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    _ipController.text = prefs.getString('wifi_printer_ip') ?? '';
  }

  Future<void> _saveIp() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter WiFi printer IP address')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifi_printer_ip', ip);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WiFi printer IP saved')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Printer Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'WiFi Printer IP Address',
                hintText: 'Example: 192.168.1.120',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveIp,
                icon: const Icon(Icons.save),
                label: const Text('Save WiFi Printer IP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
