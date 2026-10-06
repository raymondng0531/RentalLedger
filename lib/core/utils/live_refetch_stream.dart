import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Builds a stream that runs [fetch] once immediately and again whenever any
/// stream opened by [triggers] fires, emitting each result.
///
/// It guarantees the stream never stays silent. Before this, a first fetch
/// that failed or never answered was only logged, so nothing (no data and no
/// error) reached the stream. A page on that stream showed its loading
/// skeleton forever. This was seen in the iPhone Home Screen (PWA) app, where
/// the first Firestore reads after sign-in can stall.
///
/// * Each fetch is capped at [attemptTimeout], so a read that never answers
///   counts as a failure instead of hanging the stream.
/// * A failed fetch is retried with exponential backoff, starting at
///   [retryBaseDelay] and capped at [maxRetryDelay], until one succeeds.
/// * If no data has been emitted yet, the error is emitted after
///   [errorAfterFailures] consecutive failures so the page can show its error
///   state. Retrying continues, and the next success replaces the error with
///   data.
/// * Once data has been shown, a failed refetch keeps that data on screen and
///   retries quietly.
/// * Bursts of trigger events within [coalesce] share one fetch, and only the
///   newest fetch may emit, so a slow stale fetch can never overwrite a newer
///   result.
/// * A trigger that errors is logged, schedules a retry, and is re-subscribed
///   after a backoff delay. A Firestore listener stops for good on its first
///   error, and right after sign-in on web the first listen can be rejected
///   while the auth token is still reaching Firestore. Each trigger is
///   therefore passed as a factory that opens a fresh stream.
Stream<T> liveRefetchStream<T>({
  required Future<T> Function() fetch,
  required List<Stream<Object?> Function()> triggers,
  String debugLabel = 'liveRefetchStream',
  Duration coalesce = const Duration(milliseconds: 150),
  Duration attemptTimeout = const Duration(seconds: 10),
  Duration retryBaseDelay = const Duration(seconds: 1),
  Duration maxRetryDelay = const Duration(seconds: 30),
  int errorAfterFailures = 3,
}) {
  final controller = StreamController<T>();

  var cancelled = false;
  var generation = 0;
  var hasData = false;
  var consecutiveFailures = 0;
  Timer? pendingRefetch;
  Timer? pendingRetry;

  late void Function() scheduleRetry;

  Future<void> refetch() async {
    final current = ++generation;
    pendingRetry?.cancel();
    try {
      final data = await fetch().timeout(attemptTimeout);
      if (cancelled || current != generation) return;
      consecutiveFailures = 0;
      hasData = true;
      controller.add(data);
    } catch (e, st) {
      if (cancelled || current != generation) return;
      consecutiveFailures++;
      debugPrint('[$debugLabel] fetch failed '
          '(attempt $consecutiveFailures): $e');
      if (!hasData && consecutiveFailures == errorAfterFailures) {
        controller.addError(e, st);
      }
      scheduleRetry();
    }
  }

  scheduleRetry = () {
    pendingRetry?.cancel();
    if (cancelled) return;
    final exponent = math.max(0, math.min(consecutiveFailures - 1, 16));
    final delayMs = math.min(
      retryBaseDelay.inMilliseconds * (1 << exponent),
      maxRetryDelay.inMilliseconds,
    );
    pendingRetry = Timer(Duration(milliseconds: delayMs), refetch);
  };

  void scheduleRefetch() {
    pendingRefetch?.cancel();
    pendingRefetch = Timer(coalesce, refetch);
  }

  final subscriptions = List<StreamSubscription<Object?>?>.filled(
    triggers.length,
    null,
  );
  final resubscribeTimers = List<Timer?>.filled(triggers.length, null);
  final listenerFailures = List<int>.filled(triggers.length, 0);

  late void Function(int index) subscribe;
  subscribe = (index) {
    subscriptions[index] = triggers[index]().listen(
      (_) {
        listenerFailures[index] = 0;
        scheduleRefetch();
      },
      onError: (Object e) {
        debugPrint('[$debugLabel] change listener error: $e');
        if (cancelled) return;
        subscriptions[index]?.cancel();
        subscriptions[index] = null;
        consecutiveFailures++;
        scheduleRetry();
        final exponent = math.min(listenerFailures[index]++, 16);
        final delayMs = math.min(
          retryBaseDelay.inMilliseconds * (1 << exponent),
          maxRetryDelay.inMilliseconds,
        );
        resubscribeTimers[index]?.cancel();
        resubscribeTimers[index] = Timer(Duration(milliseconds: delayMs), () {
          if (!cancelled) subscribe(index);
        });
      },
    );
  };
  for (var i = 0; i < triggers.length; i++) {
    subscribe(i);
  }

  // Initial load runs immediately, so the first paint isn't delayed.
  refetch();

  controller.onCancel = () {
    cancelled = true;
    pendingRefetch?.cancel();
    pendingRetry?.cancel();
    for (final timer in resubscribeTimers) {
      timer?.cancel();
    }
    for (final sub in subscriptions) {
      sub?.cancel();
    }
  };

  return controller.stream;
}
