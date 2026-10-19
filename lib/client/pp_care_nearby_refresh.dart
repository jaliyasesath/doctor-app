/// Refreshes opening badges without replacing, appending or reordering cards.
/// A normal search, location change or Load More invalidates this snapshot.
Future<List<Map<String, dynamic>>?> refreshNearbyOpening({
  required List<Map<String, dynamic>> items,
  required int lastPage,
  required Future<Map<String, dynamic>> Function(int page) fetchPage,
  required bool Function() isCurrent,
}) async {
  if (items.isEmpty || !isCurrent()) return null;
  final openingByDoctor = <Object, dynamic>{};
  for (var page = 1; page <= lastPage; page++) {
    if (!isCurrent()) return null;
    final data = await fetchPage(page);
    if (!isCurrent()) return null;
    for (final row in (data['items'] as List).cast<Map<String, dynamic>>()) {
      final id = row['doctorId'];
      if (id != null && row.containsKey('opening')) {
        openingByDoctor[id] = row['opening'];
      }
    }
    if (data['hasMore'] != true) break;
  }
  // Only the opening payload changes. Existing distance order, queue counts,
  // identity, pagination and list length remain owned by the normal loader.
  return [
    for (final item in items)
      if (openingByDoctor.containsKey(item['doctorId']))
        {...item, 'opening': openingByDoctor[item['doctorId']]}
      else
        item,
  ];
}
