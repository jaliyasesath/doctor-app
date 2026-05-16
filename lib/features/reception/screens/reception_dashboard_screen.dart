import 'package:flutter/material.dart';

import '../../auth/data/doctor_session.dart';
import '../../patient/screens/add_patient_screen.dart' as patient_screen;
import 'reception_queue_screen.dart';
import '../../local_server/screens/reception_hotspot_connect_screen.dart';
import 'reception_patient_search_screen.dart';


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

    setState(() {
      name = doctorName;
    });
  }

  void _comingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title coming soon')),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          child: Icon(icon),
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
                color: Colors.blue,
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
  subtitle: 'Add name, age, gender, phone, address',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const patient_screen.AddPatientScreen(),
      ),
    );
  },
),

_menuCard(
  icon: Icons.qr_code_scanner,
  title: 'Connect Doctor Hotspot',
  subtitle: 'Scan Doctor QR and connect local server',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReceptionHotspotConnectScreen(),
      ),
    );
  },
),
            _menuCard(
              icon: Icons.queue,
              title: 'Today Queue',
              subtitle: 'View waiting patients in order',
              onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const ReceptionQueueScreen(initialTab: 'waiting'),
    ),
  );
},
            ),
            _menuCard(
              icon: Icons.search,
              title: 'Search Patients',
              subtitle: 'Find patient by ID, name or phone',
              onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const ReceptionPatientSearchScreen(),
    ),
  );
},
            ),
            _menuCard(
              icon: Icons.skip_next,
              title: 'Skipped Patients',
              subtitle: 'Patients skipped by doctor',
              onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const ReceptionQueueScreen(initialTab: 'skipped'),
    ),
  );
},
            ),
          ],
        ),
      ),
    );
  }
}