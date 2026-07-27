import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';

class DashboardAnalyticsScreen extends StatefulWidget {
  const DashboardAnalyticsScreen({super.key});

  @override
  State<DashboardAnalyticsScreen> createState() =>
      _DashboardAnalyticsScreenState();
}

class _DashboardAnalyticsScreenState extends State<DashboardAnalyticsScreen> {
  int todayRx = 0;
  int todayPatients = 0;
  List<Map<String, dynamic>> topMedicines = [];
  List<Map<String, dynamic>> weeklyStats = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final db = DatabaseHelper.instance;

    final rx = await db.getTodayPrescriptionCount();
    final patients = await db.getTodayPatientCount();
    final meds = await db.getTopMedicines();
    final week = await db.getLast7DaysStats();

    if (!mounted) return;

    setState(() {
      todayRx = rx;
      todayPatients = patients;
      topMedicines = meds;
      weeklyStats = week;
      loading = false;
    });
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics Dashboard"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _card("Today Rx", "$todayRx", Icons.receipt,
                            Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _card("Patients", "$todayPatients", Icons.people,
                            Colors.green)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("🔥 Top Medicines",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ...topMedicines.map((e) => ListTile(
                      leading: const Icon(Icons.medication),
                      title: Text(e['name']),
                      trailing: Text("x${e['count']}"),
                    )),
                const SizedBox(height: 20),
                const Text("📈 Last 7 Days",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ...weeklyStats.map((e) => ListTile(
                      leading: const Icon(Icons.bar_chart),
                      title: Text(e['prescription_date']),
                      trailing: Text(e['count'].toString()),
                    )),
              ],
            ),
    );
  }
}
