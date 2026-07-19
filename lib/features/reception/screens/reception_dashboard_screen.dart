import 'package:flutter/material.dart';

import '../../auth/data/doctor_session.dart';
import '../../local_server/screens/reception_hotspot_connect_screen.dart';
import '../../medicines/screens/medicine_screen.dart';
import '../../patient/screens/add_patient_screen.dart' as patient_screen;
import '../../prescription/screens/prescription_history_screen.dart';
import 'reception_bills_screen.dart';
import 'reception_patient_search_screen.dart';
import 'reception_queue_screen.dart';

class ReceptionDashboardScreen extends StatefulWidget {
  const ReceptionDashboardScreen({super.key});

  @override
  State<ReceptionDashboardScreen> createState() =>
      _ReceptionDashboardScreenState();
}

class _ReceptionDashboardScreenState extends State<ReceptionDashboardScreen> {
  String name = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final doctorName = await DoctorSession.getDoctorName();

    if (!mounted) return;
    setState(() => name = doctorName);
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue.withOpacity(0.10),
          child: Icon(icon, color: Colors.blue.shade700),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        title: const Text('Reception Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await DoctorSession.clearSession();

              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4CBF), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome Reception',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.isEmpty ? 'Clinic user' : name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _menuCard(
              icon: Icons.person_add_alt_1,
              title: 'Register Patient',
              subtitle: 'Add name, age, gender, phone and address',
              onTap: () =>
                  _open(const patient_screen.AddPatientScreen()),
            ),
            _menuCard(
              icon: Icons.qr_code_scanner,
              title: 'Connect Doctor Hotspot',
              subtitle: 'Scan Doctor QR and connect local server',
              onTap: () =>
                  _open(const ReceptionHotspotConnectScreen()),
            ),
            _menuCard(
              icon: Icons.queue,
              title: 'Today Queue',
              subtitle: 'View today and previous pending patients',
              onTap: () => _open(
                const ReceptionQueueScreen(initialTab: 'waiting'),
              ),
            ),
            _menuCard(
              icon: Icons.medication_outlined,
              title: 'Medicines',
              subtitle: 'View medicines and update doctor prices',
              onTap: () => _open(const MedicineScreen()),
            ),
            _menuCard(
              icon: Icons.search,
              title: 'Search Patients',
              subtitle: 'Find patient by ID, name or phone',
              onTap: () => _open(const ReceptionPatientSearchScreen()),
            ),
            _menuCard(
              icon: Icons.description_outlined,
              title: 'Saved Prescriptions',
              subtitle: 'View and print prescriptions',
              onTap: () => _open(
                const PrescriptionHistoryScreen(receptionMode: true),
              ),
            ),
            _menuCard(
              icon: Icons.receipt_long,
              title: 'Bills',
              subtitle: 'View bills and print receipts',
              onTap: () => _open(const ReceptionBillsScreen()),
            ),
            _menuCard(
              icon: Icons.skip_next,
              title: 'Skipped Patients',
              subtitle: 'View patients removed from the queue',
              onTap: () => _open(
                const ReceptionQueueScreen(initialTab: 'skipped'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
