import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expenses/presentation/providers/expense_provider.dart';
import '../utils/bill_history.dart';
import 'history_provider.dart';

/// The Bill History read surface, assembled from two streams that already exist.
///
/// **No new Firestore query, no new index, no new collection.** The bills come
/// from `billsProvider` — which already returns every active bill, paid and
/// unpaid, and is already ordered by `dueDate` — and the payment details come
/// from the `billPaid` events `historyProvider` already derives from
/// direct-payment transactions.
///
/// ## Why this is a plain [Provider] and not a StreamProvider
///
/// The join in [buildBillHistoryEntries] is pure, and both inputs are already
/// reactive. Deriving one value from two async sources with `Provider` keeps
/// that visible: the page watches one provider and gets loading/error/data for
/// the *combination*, rather than having to reconcile two `AsyncValue`s itself.
///
/// Status is DERIVED here (see [deriveBillStatus]) — nothing is written back,
/// so no bill document is touched by reading this page.
///
/// Filtering is deliberately NOT part of this provider: the entries are the
/// full set, and [applyBillHistoryFilters] runs over them in the page. That
/// keeps filter changes free of I/O and lets the whole filter matrix be
/// unit-tested without a widget or a network.
final billHistoryProvider = Provider<AsyncValue<List<BillHistoryEntry>>>((ref) {
  final billsAsync = ref.watch(billsProvider);

  // The filter key is only a cache key (`historyProvider` ignores it when
  // building) — Bill History always wants the unfiltered event set, so it uses
  // a stable, empty key rather than History's joined type selection.
  final eventsAsync = ref.watch(historyProvider(billHistoryEventKey));

  // A failure in EITHER source fails the whole surface: half a join is not a
  // result worth showing. Both streams are backed by the same house, so in
  // practice they fail together.
  final error = billsAsync.error ?? eventsAsync.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      billsAsync.stackTrace ??
          eventsAsync.stackTrace ??
          StackTrace.fromString('Bill History sources failed'),
    );
  }

  final bills = billsAsync.valueOrNull;
  final events = eventsAsync.valueOrNull;

  // Loading until BOTH have data — showing bills with no payments attached
  // would render every settled bill as if nothing had been recorded.
  if (bills == null || events == null) return const AsyncValue.loading();

  return AsyncValue.data(buildBillHistoryEntries(bills: bills, events: events));
});

/// The cache key for the event stream Bill History reads.
///
/// Named rather than inlined so [refreshBillHistory] and the provider cannot
/// drift apart and silently watch two different provider instances.
const billHistoryEventKey = '';

/// Re-runs both of [billHistoryProvider]'s sources.
///
/// Invalidating `billHistoryProvider` alone would re-run its build body but
/// reuse the sources' cached error, so a retry must invalidate the sources;
/// the derived provider then recomputes on its own.
void refreshBillHistory(WidgetRef ref) {
  ref.invalidate(billsProvider);
  ref.invalidate(historyProvider(billHistoryEventKey));
}
