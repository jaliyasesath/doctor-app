import 'dart:async';

import 'package:doctor_app/core/concurrency/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same pending mutation is executed only once', () async {
    final guard = SingleFlight();
    final completer = Completer<int>();
    var executions = 0;

    Future<int> operation() {
      executions++;
      return completer.future;
    }

    final first = guard.run<int>('save-prescription', operation);
    final second = guard.run<int>('save-prescription', operation);

    expect(executions, 1);
    expect(identical(first, second), isTrue);
    completer.complete(42);
    expect(await first, 42);
    expect(await second, 42);
  });

  test('completed mutation may be executed again', () async {
    final guard = SingleFlight();
    var executions = 0;

    Future<int> operation() async => ++executions;

    expect(await guard.run<int>('save', operation), 1);
    await Future<void>.delayed(Duration.zero);
    expect(await guard.run<int>('save', operation), 2);
  });

  test('failed mutation is released for retry', () async {
    final guard = SingleFlight();
    var executions = 0;

    Future<int> operation() async {
      executions++;
      if (executions == 1) throw StateError('failed');
      return 7;
    }

    await expectLater(
      guard.run<int>('save', operation),
      throwsA(isA<StateError>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await guard.run<int>('save', operation), 7);
    expect(executions, 2);
  });
}
