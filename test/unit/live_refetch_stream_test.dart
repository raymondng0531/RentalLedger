import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/live_refetch_stream.dart';

/// Tests for [liveRefetchStream], the refetch-on-change stream behind the
/// dashboard. The bug it fixes: a first fetch that failed or never answered
/// left the stream silent, so the dashboard showed loading skeletons forever
/// (iPhone Home Screen app, right after sign-in).
void main() {
  // Short timings so the tests run in real time.
  const coalesce = Duration(milliseconds: 5);
  const timeout = Duration(milliseconds: 40);
  const retry = Duration(milliseconds: 10);
  const maxRetry = Duration(milliseconds: 40);

  Stream<T> build<T>(
    Future<T> Function() fetch, {
    List<Stream<Object?> Function()> triggers = const [],
    int errorAfterFailures = 3,
  }) =>
      liveRefetchStream<T>(
        fetch: fetch,
        triggers: triggers,
        coalesce: coalesce,
        attemptTimeout: timeout,
        retryBaseDelay: retry,
        maxRetryDelay: maxRetry,
        errorAfterFailures: errorAfterFailures,
      );

  test('emits the initial fetch immediately', () async {
    final stream = build(() async => 42);
    expect(await stream.first, 42);
  });

  test('a failing first fetch is retried until it succeeds', () async {
    var calls = 0;
    final stream = build(() async {
      calls++;
      if (calls < 3) throw Exception('transient');
      return 'ok';
    }, errorAfterFailures: 99);
    expect(await stream.first, 'ok');
    expect(calls, 3);
  });

  test('a first fetch that never answers times out and is retried', () async {
    var calls = 0;
    final stream = build(() {
      calls++;
      // The first read hangs forever, as seen in the iPhone PWA.
      if (calls == 1) return Completer<String>().future;
      return Future.value('loaded');
    });
    expect(await stream.first.timeout(const Duration(seconds: 2)), 'loaded');
    expect(calls, 2);
  });

  test('persistent failure surfaces an error, then recovers to data', () async {
    var calls = 0;
    final events = <Object>[];
    final done = Completer<void>();
    final sub = build(() async {
      calls++;
      if (calls <= 3) throw Exception('down');
      return 'back';
    }).listen(
      (v) {
        events.add(v);
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e) => events.add('error'),
    );
    await done.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    // Exactly one error (after the 3rd failure), then the data.
    expect(events, ['error', 'back']);
  });

  test('once data is shown, a failed refetch keeps it and emits no error',
      () async {
    final trigger = StreamController<Object?>();
    var calls = 0;
    final events = <Object>[];
    final second = Completer<void>();
    final sub = build(() async {
      calls++;
      if (calls == 2) throw Exception('blip');
      return 'v$calls';
    }, triggers: [() => trigger.stream], errorAfterFailures: 1).listen(
      (v) {
        events.add(v);
        if (events.length == 2 && !second.isCompleted) second.complete();
      },
      onError: (Object e) => events.add('error'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    trigger.add(null); // refetch #2 fails, then a retry (#3) succeeds
    await second.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    await trigger.close();
    expect(events, ['v1', 'v3']);
  });

  test('a burst of change events shares one refetch', () async {
    final trigger = StreamController<Object?>();
    var calls = 0;
    final sub = build(() async => ++calls, triggers: [() => trigger.stream])
        .listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 5; i++) {
      trigger.add(null);
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await sub.cancel();
    await trigger.close();
    expect(calls, 2); // initial + one coalesced refetch
  });

  test('a stale slow fetch never overwrites a newer result', () async {
    final trigger = StreamController<Object?>();
    final slow = Completer<String>();
    var calls = 0;
    final events = <String>[];
    final sub = build(() {
      calls++;
      if (calls == 1) return slow.future; // initial, slow
      return Future.value('fresh');
    }, triggers: [() => trigger.stream]).listen(events.add);
    trigger.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    slow.complete('stale');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    await trigger.close();
    expect(events, ['fresh']);
  });

  test('a change listener error retries the fetch and re-subscribes',
      () async {
    // Each subscription gets a fresh controller, like a new Firestore listen.
    final opened = <StreamController<Object?>>[];
    Stream<Object?> openTrigger() {
      final c = StreamController<Object?>();
      opened.add(c);
      return c.stream;
    }

    var calls = 0;
    final third = Completer<void>();
    final sub = build(() async => ++calls, triggers: [openTrigger])
        .listen((v) {
      if (v == 3 && !third.isCompleted) third.complete();
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // First listen rejected (auth token not yet attached).
    opened.first.addError(Exception('permission-denied'));
    // The error schedules a refetch (#2) and a re-subscribe.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(opened.length, 2);
    // The NEW listener delivers live changes again.
    opened.last.add(null);
    await third.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    for (final c in opened) {
      await c.close();
    }
    expect(calls, 3);
  });

  test('cancelling stops further retries', () async {
    var calls = 0;
    final sub = build<int>(() async {
      calls++;
      throw Exception('down');
    }, errorAfterFailures: 99)
        .listen((_) {}, onError: (_) {});
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await sub.cancel();
    final afterCancel = calls;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(calls, afterCancel);
  });
}
