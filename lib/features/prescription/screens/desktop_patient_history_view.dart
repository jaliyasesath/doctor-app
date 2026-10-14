import 'package:flutter/material.dart';

class DesktopPatientHistoryView extends StatelessWidget {
  const DesktopPatientHistoryView({
    super.key,
    required this.searchController,
    required this.scrollController,
    required this.patients,
    required this.total,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.gender,
    required this.visitFilter,
    required this.sort,
    required this.alertsOnly,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onFiltersChanged,
    required this.onResetFilters,
    required this.onOpenPatient,
    required this.onLoadMore,
  });

  final TextEditingController searchController;
  final ScrollController scrollController;
  final List<Map<String, dynamic>> patients;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String gender;
  final String visitFilter;
  final String sort;
  final bool alertsOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final void Function(String gender, String visits, String sort, bool alerts)
      onFiltersChanged;
  final VoidCallback onResetFilters;
  final ValueChanged<Map<String, dynamic>> onOpenPatient;
  final Future<void> Function() onLoadMore;

  String _value(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Patient History',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 5),
              const Text('Search patient records and review complete visit history.',
                  style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              _filters(),
              const SizedBox(height: 14),
              Row(children: [
                Text('$total patient${total == 1 ? '' : 's'} found',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const Spacer(),
                if (gender != 'All' || visitFilter != 'all' || alertsOnly || sort != 'recent')
                  TextButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
              ]),
              const SizedBox(height: 8),
              Expanded(child: _content()),
            ]),
          ),
        ),
      );

  Widget _filters() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              decoration: InputDecoration(
                hintText: 'Name, phone, address or patient ID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _dropdown('Gender', gender, const {
            'All': 'All genders',
            'Male': 'Male',
            'Female': 'Female',
            'Other': 'Other',
          }, (value) => onFiltersChanged(value, visitFilter, sort, alertsOnly)),
          const SizedBox(width: 10),
          _dropdown('Visits', visitFilter, const {
            'all': 'All patients',
            'withVisits': 'With visits',
            'withoutVisits': 'No visits',
          }, (value) => onFiltersChanged(gender, value, sort, alertsOnly)),
          const SizedBox(width: 10),
          _dropdown('Sort', sort, const {
            'recent': 'Recent visit',
            'name': 'Name A-Z',
            'mostVisits': 'Most visits',
          }, (value) => onFiltersChanged(gender, visitFilter, value, alertsOnly)),
          const SizedBox(width: 8),
          FilterChip(
            selected: alertsOnly,
            label: const Text('Medical alerts'),
            avatar: const Icon(Icons.warning_amber_rounded, size: 18),
            onSelected: (value) =>
                onFiltersChanged(gender, visitFilter, sort, value),
          ),
        ]),
      );

  Widget _dropdown(String label, String value, Map<String, String> options,
          ValueChanged<String> changed) =>
      SizedBox(
        width: 150,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: options.entries
              .map((x) => DropdownMenuItem(value: x.key, child: Text(x.value)))
              .toList(),
          onChanged: (next) {
            if (next != null) changed(next);
          },
        ),
      );

  Widget _content() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (patients.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search_rounded, size: 56, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('No patients found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 5),
          Text('Change the search text or filters and try again.',
              style: TextStyle(color: Color(0xFF64748B))),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            Expanded(flex: 28, child: Text('PATIENT')),
            Expanded(flex: 16, child: Text('PHONE')),
            Expanded(flex: 12, child: Text('VISITS')),
            Expanded(flex: 17, child: Text('LAST VISIT')),
            Expanded(flex: 20, child: Text('MEDICAL ALERT')),
            SizedBox(width: 64, child: Text('OPEN', textAlign: TextAlign.right)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: patients.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _row(patients[index]),
          ),
        ),
        if (isLoadingMore)
          const LinearProgressIndicator(minHeight: 2)
        else if (hasMore)
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load more patients'),
            ),
          ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> patient) {
    final name = _value(patient, ['patient_name', 'patientName']);
    final age = _value(patient, ['patient_age', 'patientAge', 'age']);
    final genderValue =
        _value(patient, ['patient_gender', 'patientGender', 'gender']);
    final phone = _value(patient, ['phone_number', 'phoneNumber']);
    final alert = _value(patient, ['important_alerts', 'allergies', 'chronic_diseases']);
    final visits = patient['visit_count'] ?? 0;
    final lastVisit = _value(patient, ['last_visit_date']);
    return InkWell(
      onTap: () => onOpenPatient(patient),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(children: [
          Expanded(
            flex: 28,
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE6FFFB),
                foregroundColor: const Color(0xFF0F766E),
                child: Text(name.isEmpty ? 'P' : name[0].toUpperCase()),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Unnamed Patient' : name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${age.isEmpty ? 'Age -' : '$age yrs'} • ${genderValue.isEmpty ? '-' : genderValue}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
            ]),
          ),
          Expanded(flex: 16, child: Text(phone.isEmpty ? '-' : phone)),
          Expanded(flex: 12, child: Text('$visits')),
          Expanded(flex: 17, child: Text(lastVisit.isEmpty ? 'No visits yet' : lastVisit)),
          Expanded(
            flex: 20,
            child: Text(alert.isEmpty ? 'None recorded' : alert,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: alert.isEmpty ? const Color(0xFF64748B) : const Color(0xFFBE123C))),
          ),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Open patient history',
                onPressed: () => onOpenPatient(patient),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
