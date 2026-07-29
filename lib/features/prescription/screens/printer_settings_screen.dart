import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/bluetooth_thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final BluetoothThermalPrinterService _bluetooth =
      BluetoothThermalPrinterService();
  final TextEditingController _ipController = TextEditingController();

  List<BluetoothInfo> _printers = const [];
  BluetoothInfo? _selected;
  bool _loading = true;
  bool _working = false;
  bool _connected = false;
  String _savedName = '';
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = '';
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _ipController.text = prefs.getString('wifi_printer_ip') ?? '';
      final savedAddress = await _bluetooth.savedAddress;
      final savedName = await _bluetooth.savedName;

      final bluetoothOn = await _bluetooth.isBluetoothEnabled.timeout(
        const Duration(seconds: 5),
      );
      if (!bluetoothOn) {
        throw StateError('Bluetooth is turned off. Turn it on and tap Retry.');
      }

      final hasPermission = await _bluetooth.hasPermission.timeout(
        const Duration(seconds: 5),
      );
      if (!hasPermission) {
        throw StateError(
          'Bluetooth permission is not allowed. Open phone Settings > Apps > Private Practice > Permissions > Nearby devices and select Allow.',
        );
      }

      final printers = await _bluetooth.pairedPrinters().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'Printer search timed out. Pair BT-58D in phone Bluetooth settings and tap Retry.',
            ),
          );
      BluetoothInfo? selected;
      for (final printer in printers) {
        if (printer.macAdress == savedAddress) {
          selected = printer;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _selected = selected;
        _savedName = savedName ?? '';
        _loading = false;
        _loadError = '';
      });
      await _refreshConnection();
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('TimeoutException: ', '');
      setState(() {
        _loading = false;
        _loadError = message;
        _printers = const [];
        _selected = null;
      });
    }
  }

  Future<void> _refreshConnection() async {
    final connected = await _bluetooth.isConnected;
    if (mounted) setState(() => _connected = connected);
  }

  Future<void> _connect() async {
    final printer = _selected;
    if (printer == null) {
      _message('Select BT-58D from the paired printer list.', error: true);
      return;
    }
    setState(() => _working = true);
    try {
      final bluetoothOn = await _bluetooth.isBluetoothEnabled;
      if (!bluetoothOn) {
        _message('Turn on Bluetooth and try again.', error: true);
        return;
      }
      final connected = await _bluetooth.connect(printer);
      if (!mounted) return;
      setState(() {
        _connected = connected;
        if (connected) _savedName = printer.name;
      });
      _message(
        connected
            ? '${printer.name} connected and saved.'
            : 'Connection failed. Pair BT-58D in phone Bluetooth settings first.',
        error: !connected,
      );
    } catch (error) {
      _message('Printer connection failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _working = true);
    try {
      final printed = await _bluetooth.printTest();
      if (!mounted) return;
      setState(() => _connected = printed);
      _message(
        printed
            ? 'BT-58D test print sent.'
            : 'Printer is not connected. Select and connect BT-58D first.',
        error: !printed,
      );
    } catch (error) {
      _message('Test print failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _disconnect() async {
    await _bluetooth.disconnect();
    if (!mounted) return;
    setState(() => _connected = false);
    _message('Printer disconnected.');
  }

  Future<void> _saveWifiIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifi_printer_ip', _ipController.text.trim());
    _message('WiFi printer IP saved.');
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : const Color(0xFF0F766E),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thermal Printer')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Searching for paired printers...'),
                ],
              ),
            )
          : _loadError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bluetooth_disabled,
                          size: 54,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Bluetooth printer could not be loaded',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _loadError,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Card(
                      color: const Color(0xFFF0FDF4),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BT-58D Bluetooth Printer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF064E3B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _connected
                                  ? 'Connected: ${_savedName.isEmpty ? 'BT-58D' : _savedName}'
                                  : 'Not connected',
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<BluetoothInfo>(
                              value: _selected,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Paired Bluetooth printer',
                                border: OutlineInputBorder(),
                              ),
                              items: _printers
                                  .map(
                                    (printer) => DropdownMenuItem(
                                      value: printer,
                                      child: Text(
                                        '${printer.name} (${printer.macAdress})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _working
                                  ? null
                                  : (value) =>
                                      setState(() => _selected = value),
                            ),
                            if (_printers.isEmpty) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'No printer found. Pair BT-58D from the phone Bluetooth settings, then tap Refresh.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _working ? null : _connect,
                                    icon: const Icon(Icons.bluetooth_connected),
                                    label: const Text('Connect'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Refresh paired printers',
                                  onPressed: _working ? null : _load,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _working ? null : _testPrint,
                                    icon: const Icon(Icons.print),
                                    label: const Text('Test Print'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _working || !_connected
                                        ? null
                                        : _disconnect,
                                    icon: const Icon(Icons.link_off),
                                    label: const Text('Disconnect'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'iPhone / WiFi printer fallback',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'WiFi printer IP address',
                        hintText: 'Example: 192.168.1.120',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _saveWifiIp,
                      icon: const Icon(Icons.save),
                      label: const Text('Save WiFi Printer IP'),
                    ),
                  ],
                ),
    );
  }
}
