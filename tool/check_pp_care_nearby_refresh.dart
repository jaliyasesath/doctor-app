// Run from the Flutter project root: dart tool/check_pp_care_nearby_refresh.dart
import 'dart:async';
import 'dart:io';
import 'package:doctor_app/client/pp_care_nearby_refresh.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final original = <Map<String, dynamic>>[
    {'doctorId': 1, 'opening': 'old-1', 'waitingCount': 4},
    {'doctorId': 2, 'opening': 'old-2', 'waitingCount': 8},
    {'doctorId': 3, 'opening': 'old-3', 'waitingCount': 2},
  ];
  final calls = <int>[];
  final refreshed = await refreshNearbyOpening(
    items: original,
    lastPage: 2,
    isCurrent: () => true,
    fetchPage: (page) async {
      calls.add(page);
      return {
        'hasMore': true,
        'items': page == 1
            ? <Map<String, dynamic>>[
                {'doctorId': 2, 'opening': 'new-2', 'waitingCount': 99},
                {'doctorId': 99, 'opening': 'new-doctor'},
              ]
            : <Map<String, dynamic>>[
                {'doctorId': 3, 'opening': 'new-3'},
                {'doctorId': 1, 'opening': 'new-1'},
              ],
      };
    },
  );
  check(calls.join(',') == '1,2', 'All loaded pages must refresh');
  check(refreshed!.map((r) => r['doctorId']).join(',') == '1,2,3',
      'Preserve existing card order and length, ignore new doctors');
  check(refreshed.map((r) => r['opening']).join(',') == 'new-1,new-2,new-3',
      'Update by identity across page boundaries');
  check(
      refreshed.first['waitingCount'] == 4 &&
          refreshed[1]['waitingCount'] == 8 &&
          original.first['opening'] == 'old-1',
      'Do not mutate unrelated card fields or original snapshot');
  stdout.writeln(
      'PASS: loaded pages, card identity/order, status merge, original snapshot');

  var shortCalls = 0;
  final missing = await refreshNearbyOpening(
    items: original,
    lastPage: 3,
    isCurrent: () => true,
    fetchPage: (_) async {
      shortCalls++;
      return {'hasMore': false, 'items': <Map<String, dynamic>>[]};
    },
  );
  check(shortCalls == 1 && identical(missing![2], original[2]),
      'Stop at last server page and retain missing cards');
  stdout.writeln('PASS: shrinking result set retains loaded cards');

  var current = true;
  final pending = Completer<Map<String, dynamic>>();
  final staleFuture = refreshNearbyOpening(
    items: original,
    lastPage: 2,
    isCurrent: () => current,
    fetchPage: (_) => pending.future,
  );
  current = false;
  pending.complete({'hasMore': true, 'items': <Map<String, dynamic>>[]});
  check(
      await staleFuture == null, 'Discard response after search/load/dispose');
  stdout.writeln('PASS: stale response is discarded');

  var failed = false;
  try {
    await refreshNearbyOpening(
      items: original,
      lastPage: 2,
      isCurrent: () => true,
      fetchPage: (page) async {
        if (page == 2) throw StateError('offline');
        return {
          'hasMore': true,
          'items': <Map<String, dynamic>>[
            {'doctorId': 1, 'opening': 'partial'}
          ],
        };
      },
    );
  } on StateError {
    failed = true;
  }
  check(failed && original.first['opening'] == 'old-1',
      'Failure on later page must not apply a partial update');
  stdout.writeln('PASS: network failure does not partially change cards');

  for (final rows in [<Map<String, dynamic>>[], original]) {
    var requested = false;
    await refreshNearbyOpening(
      items: rows,
      lastPage: 2,
      isCurrent: () => rows.isEmpty,
      fetchPage: (_) async {
        requested = true;
        return {};
      },
    );
    check(!requested, 'Empty/stale snapshots must not request pages');
  }
  stdout.writeln('PASS: empty and invalidated lists do not request pages');
  stdout.writeln('All Nearby opening-refresh regression checks passed.');
}
