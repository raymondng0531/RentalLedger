import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';
import 'package:rental_ledger/features/history/presentation/utils/bill_history.dart';
import 'package:rental_ledger/features/history/presentation/utils/filter_periods.dart';

/// Unit cover for the pure Bill History rules: derived status, the bill↔payment
/// join, the filing date, and every filter predicate.
///
/// Every case here pins "today" rather than reading the clock, so the boundary
/// tests mean what they say on any day the suite runs.
void main() {
  // A fixed "today". Bills are built relative to it.
  final today = DateTime(2026, 9, 10);

  /// A bill due [dueInDays] from [today] (negative = in the past).
  BillEntity bill({
    String billId = 'bill-1',
    String title = 'Electricity',
    double? amount = 120.0,
    int dueInDays = 5,
    String categoryId = 'utilities',
    bool isPaid = false,
    bool isRecurring = false,
    bool isActive = true,
    DateTime? createdAt,
  }) {
    return BillEntity(
      billId: billId,
      houseId: 'house-1',
      title: title,
      amount: amount,
      dueDate: today.add(Duration(days: dueInDays)),
      categoryId: categoryId,
      isActive: isActive,
      isRecurring: isRecurring,
      isPaid: isPaid,
      createdAt: createdAt ?? DateTime(2026, 8, 3),
    );
  }

  /// A `billPaid` event, as History derives it from a direct-payment
  /// transaction whose notes begin "Bill: ".
  HistoryEvent paid({
    String transactionId = 'tx-1',
    String? refId = 'bill-1',
    String title = 'Electricity',
    double amount = -120.0,
    DateTime? date,
    String? userId = 'user-treasurer',
    String? periodLabel = '2026-09',
    String? paymentMethod = 'Bank Transfer',
    String? receiptUrl,
    String? categoryId,
  }) {
    return HistoryEvent(
      id: 'bill-paid-$transactionId',
      type: HistoryEventType.billPaid,
      refId: refId,
      title: title,
      amount: amount,
      date: date ?? DateTime(2026, 9, 5),
      categoryId: categoryId,
      userId: userId,
      paymentMethod: paymentMethod,
      periodLabel: periodLabel,
      receiptUrl: receiptUrl,
    );
  }

  group('derived status — §2', () {
    test('1. isPaid true is Paid', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(isPaid: true, dueInDays: -30)],
        events: const [],
        now: today,
      ).single;

      expect(entry.status, BillHistoryStatus.paid);
      expect(entry.isPaid, isTrue);
    });

    test('2. not paid and not overdue is Upcoming', () {
      final entry = buildBillHistoryEntries(
        bills: [bill()],
        events: const [],
        now: today,
      ).single;

      expect(entry.status, BillHistoryStatus.upcoming);
    });

    test('3. not paid and past due is Overdue', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(dueInDays: -1)],
        events: const [],
        now: today,
      ).single;

      expect(entry.status, BillHistoryStatus.overdue);
      expect(entry.isOverdue, isTrue);
    });

    test('4. the due-date boundary: due TODAY is Upcoming, due YESTERDAY is '
        'Overdue, due TOMORROW is Upcoming', () {
      BillHistoryStatus statusAt(int dueInDays) => buildBillHistoryEntries(
        bills: [bill(dueInDays: dueInDays)],
        events: const [],
        now: today,
      ).single.status;

      expect(statusAt(0), BillHistoryStatus.upcoming);
      expect(statusAt(-1), BillHistoryStatus.overdue);
      expect(statusAt(1), BillHistoryStatus.upcoming);
    });

    test('4b. a PAID bill past its due date is Paid, never Overdue', () {
      // Paid wins outright: status is derived, not a bare date comparison.
      final entry = buildBillHistoryEntries(
        bills: [bill(isPaid: true, dueInDays: -90)],
        events: const [],
        now: today,
      ).single;

      expect(entry.status, BillHistoryStatus.paid);
      expect(entry.isOverdue, isFalse);
    });

    test('4c. the derivation agrees with BillEntity.isOverdue on the real '
        'clock', () {
      // deriveBillStatus mirrors daysLeft's day-truncated comparison. This
      // pins the mirror: if the entity's rule ever changes, this fails.
      for (final dueInDays in [-30, -1, 0, 1, 30]) {
        final b = bill(dueInDays: dueInDays);
        final derived = deriveBillStatus(b);

        expect(
          derived == BillHistoryStatus.overdue,
          b.isOverdue,
          reason: 'dueInDays=$dueInDays',
        );
      }
    });
  });

  group('the bill ↔ payment join — §5', () {
    test('a recorded payment attaches to its bill and carries the details', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(isPaid: true)],
        events: [
          paid(
            date: DateTime(2026, 9, 5),
            receiptUrl: 'https://example.com/receipt.jpg',
          ),
        ],
        now: today,
      ).single;

      final payment = entry.latestPayment!;
      expect(payment.date, DateTime(2026, 9, 5));
      expect(payment.periodLabel, '2026-09');
      expect(payment.paymentMethod, 'Bank Transfer');
      expect(payment.receiptUrl, 'https://example.com/receipt.jpg');
      // The recorder — NOT described as the payer anywhere.
      expect(payment.recordedByUserId, 'user-treasurer');
      expect(payment.eventId, 'bill-paid-tx-1');
    });

    test('a payment pointing at a different bill does not attach', () {
      final entry = buildBillHistoryEntries(
        bills: [bill()],
        events: [paid(refId: 'bill-2')],
        now: today,
      ).single;

      expect(entry.payments, isEmpty);
      expect(entry.latestPayment, isNull);
    });

    test('a recurring bill keeps ONE id, so its payments accumulate', () {
      // Each month's settlement is another transaction against the same
      // billId, because markBillPaid rolls the bill forward in place.
      final entry = buildBillHistoryEntries(
        bills: [bill(isRecurring: true)],
        events: [
          paid(transactionId: 'tx-aug', date: DateTime(2026, 8, 5)),
          paid(transactionId: 'tx-sep', date: DateTime(2026, 9, 5)),
        ],
        now: today,
      ).single;

      expect(entry.payments.map((p) => p.eventId), [
        'bill-paid-tx-sep',
        'bill-paid-tx-aug',
      ], reason: 'newest first');
    });

    test('5. a recurring bill that has rolled forward reads as Upcoming '
        'again, with its payment history intact', () {
      // The known recurring-bill behaviour: settling one rolls it to next
      // month with isPaid back to false. It is genuinely due again, so
      // Upcoming is the honest status — its history is not lost, it is on the
      // row.
      final entry = buildBillHistoryEntries(
        bills: [bill(isRecurring: true)],
        events: [paid(date: DateTime(2026, 8, 5))],
        now: today,
      ).single;

      expect(entry.status, BillHistoryStatus.upcoming);
      expect(entry.payments, hasLength(1));
    });

    test('6. an amount-bearing paid bill reports its amount and payment', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(isPaid: true)],
        events: [paid()],
        now: today,
      ).single;

      expect(entry.hasAmount, isTrue);
      expect(entry.amount, 120.0);
      expect(entry.latestPayment!.amount, -120.0);
    });

    test('7. an amountless bill keeps a NULL amount — never RM 0.00', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(amount: null, isPaid: true)],
        events: const [],
        now: today,
      ).single;

      expect(entry.hasAmount, isFalse);
      expect(entry.amount, isNull);
      expect(entry.status, BillHistoryStatus.paid);
    });

    test('7b. an amountless bill has NO payment record at all', () {
      // markBillPaid writes a transaction only when the bill has an amount,
      // so settling an amountless bill leaves no money-movement trail. Nothing
      // can be invented for it, and the row says so by having no payments.
      final entry = buildBillHistoryEntries(
        bills: [bill(amount: null, isPaid: true)],
        events: const [],
        now: today,
      ).single;

      expect(entry.payments, isEmpty);
      expect(entry.recordedByUserId, isNull);
    });

    test('a payment that matched no bill is dropped, not rendered as a row', () {
      // The deleted-bill / failed-title-lookup case: the event fell back to
      // its transactionId, which matches no bill. Bill History is
      // bill-centric, so no synthetic row appears. Known limitation.
      final entries = buildBillHistoryEntries(
        bills: [bill()],
        events: [
          paid(transactionId: 'tx-orphan', refId: 'tx-orphan'),
        ],
        now: today,
      );

      expect(entries, hasLength(1));
      expect(entries.single.payments, isEmpty);
    });

    test('a billPaid event with a null refId is ignored', () {
      final entry = buildBillHistoryEntries(
        bills: [bill()],
        events: [paid(refId: null)],
        now: today,
      ).single;

      expect(entry.payments, isEmpty);
    });

    test('two bills sharing a title can have their payments cross-attached — '
        'the known title-linking limitation', () {
      // billIdByTitle collapses same-titled bills, so both events resolve to
      // whichever id won. Preserved, documented and pinned rather than fixed.
      final entries = buildBillHistoryEntries(
        bills: [
          bill(billId: 'bill-a', title: 'Water'),
          bill(billId: 'bill-b', title: 'Water'),
        ],
        // Both events resolved to bill-a, as the title lookup would.
        events: [
          paid(refId: 'bill-a', title: 'Water'),
          paid(transactionId: 'tx-2', refId: 'bill-a', title: 'Water'),
        ],
        now: today,
      );

      final a = entries.firstWhere((e) => e.billId == 'bill-a');
      final b = entries.firstWhere((e) => e.billId == 'bill-b');

      expect(a.payments, hasLength(2));
      expect(b.payments, isEmpty);
    });

    test('non-bill events in the stream are ignored', () {
      final entry = buildBillHistoryEntries(
        bills: [bill()],
        events: [
          HistoryEvent(
            id: 'dep-1',
            type: HistoryEventType.deposit,
            refId: 'bill-1', // same id, wrong type
            amount: 500,
            date: DateTime(2026, 9, 2),
          ),
          HistoryEvent(
            id: 'bill-created-bill-1',
            type: HistoryEventType.billCreated,
            refId: 'bill-1',
            amount: 120,
            date: DateTime(2026, 8, 3),
          ),
        ],
        now: today,
      ).single;

      expect(entry.payments, isEmpty);
    });
  });

  group('the filing date — which date a row is filtered and grouped by', () {
    test('a Paid bill files under its PAYMENT date, not its due date', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(isPaid: true, dueInDays: -10)],
        events: [paid(date: DateTime(2026, 9, 5))],
        now: today,
      ).single;

      expect(entry.filterDate, DateTime(2026, 9, 5));
    });

    test('a Paid bill with no recorded payment falls back to its due date', () {
      // Every amountless bill lands here.
      final entry = buildBillHistoryEntries(
        bills: [bill(amount: null, isPaid: true, dueInDays: -10)],
        events: const [],
        now: today,
      ).single;

      expect(entry.filterDate, entry.dueDate);
    });

    test('an Upcoming bill files under its DUE date', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(dueInDays: 20)],
        events: const [],
        now: today,
      ).single;

      expect(entry.filterDate, entry.dueDate);
    });

    test('an Overdue bill files under its DUE date', () {
      final entry = buildBillHistoryEntries(
        bills: [bill(dueInDays: -20)],
        events: const [],
        now: today,
      ).single;

      expect(entry.filterDate, entry.dueDate);
    });
  });

  group('ordering — 15', () {
    test('rows come back newest first, by filing date', () {
      final entries = buildBillHistoryEntries(
        bills: [
          bill(billId: 'old', dueInDays: -60, isPaid: true),
          bill(billId: 'new', dueInDays: 30),
          bill(billId: 'mid'),
        ],
        events: [
          paid(refId: 'old', date: today.subtract(const Duration(days: 60))),
        ],
        now: today,
      );

      expect(entries.map((e) => e.billId), ['new', 'mid', 'old']);
    });

    test('a paid bill is ordered by when it was paid, not when it was due', () {
      // 'due-late' is due soonest but was paid LAST, so it sorts first.
      final entries = buildBillHistoryEntries(
        bills: [
          bill(billId: 'due-late', dueInDays: 1, isPaid: true),
          bill(billId: 'due-early', dueInDays: -30, isPaid: true),
        ],
        events: [
          paid(transactionId: 't1', refId: 'due-late', date: DateTime(2026, 9, 9)),
          paid(transactionId: 't2', refId: 'due-early', date: DateTime(2026, 8, 3)),
        ],
        now: today,
      );

      expect(entries.map((e) => e.billId), ['due-late', 'due-early']);
    });
  });

  group('filters — search, status, category, member, period', () {
    const filters = BillHistoryFilters();

    List<BillHistoryEntry> build() => buildBillHistoryEntries(
      bills: [
        bill(billId: 'elec'),
        bill(billId: 'water', title: 'Water Bill'),
        bill(
          billId: 'wifi',
          title: 'Internet',
          categoryId: 'internet',
          dueInDays: -5,
        ),
        bill(
          billId: 'paid-one',
          title: 'Rental',
          categoryId: 'rental',
          isPaid: true,
        ),
      ],
      events: [
        paid(
          refId: 'paid-one',
          title: 'Rental',
          date: DateTime(2026, 9, 5),
        ),
        paid(
          refId: 'elec',
          date: DateTime(2026, 9, 6),
          userId: 'user-member',
        ),
      ],
      now: today,
    );

    test('no filters returns everything, in order', () {
      final result = applyBillHistoryFilters(build(), filters, now: today);
      expect(result, hasLength(4));
    });

    test('11. search matches the bill title, case-insensitively', () {
      final result = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(searchQuery: 'elect'),
        now: today,
      );

      expect(result.map((e) => e.billId), ['elec']);
    });

    test('11b. search matches a title substring anywhere in the title', () {
      final result = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(searchQuery: 'BILL'),
        now: today,
      );

      expect(result.map((e) => e.billId), ['water']);
    });

    test('11c. blank search does not filter', () {
      for (final query in ['', '   ']) {
        final result = applyBillHistoryFilters(
          build(),
          BillHistoryFilters(searchQuery: query),
          now: today,
        );
        expect(result, hasLength(4), reason: 'query="$query"');
      }
    });

    test('12. the status filter selects exactly one derived status', () {
      final overdue = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(statuses: {BillHistoryStatus.overdue}),
        now: today,
      );
      expect(overdue.map((e) => e.billId), ['wifi']);

      final upcoming = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(statuses: {BillHistoryStatus.upcoming}),
        now: today,
      );
      expect(upcoming.map((e) => e.billId), ['elec', 'water']);

      final paid = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(statuses: {BillHistoryStatus.paid}),
        now: today,
      );
      expect(paid.map((e) => e.billId), ['paid-one']);
    });

    test('10. the category filter matches the row\'s resolved category', () {
      final result = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(categoryId: 'utilities'),
        now: today,
      );

      expect(result.map((e) => e.billId), ['elec', 'water']);
    });

    test('the row\'s category falls back to the payment\'s when the bill has '
        'none', () {
      final entries = buildBillHistoryEntries(
        bills: [bill(billId: 'b', categoryId: '')],
        events: [paid(refId: 'b', categoryId: 'from-transaction')],
        now: today,
      );

      expect(entries.single.categoryId, 'from-transaction');
    });

    test('13. the member filter matches the RECORDER of the payment', () {
      final asTreasurer = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(memberUserId: 'user-treasurer'),
        now: today,
      );
      expect(asTreasurer.map((e) => e.billId), ['paid-one']);

      final asMember = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(memberUserId: 'user-member'),
        now: today,
      );
      expect(asMember.map((e) => e.billId), ['elec']);
    });

    test('14. a member filter drops every row with no recorded payment — '
        'billCreated carries no user, and an unpaid bill has no payment at all',
        () {
      final result = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(memberUserId: 'user-treasurer'),
        now: today,
      );

      // 'wifi' (Overdue) and 'water' (Upcoming) have no payment, so no
      // attribution exists to match — they cannot appear, and the UI must not
      // imply they belong to someone else.
      expect(result.map((e) => e.billId), isNot(contains('wifi')));
      expect(result.map((e) => e.billId), isNot(contains('water')));
    });

    test('14b. a member filter cannot match a bill that has no payment, even '
        'when that member is the only member', () {
      final entries = buildBillHistoryEntries(
        bills: [bill(billId: 'unpaid', dueInDays: 3)],
        events: const [],
        now: today,
      );

      expect(
        applyBillHistoryFilters(
          entries,
          const BillHistoryFilters(memberUserId: 'user-treasurer'),
          now: today,
        ),
        isEmpty,
      );
    });

    test('8. period presets filter by the row\'s filing date', () {
      // today is 2026-09-10.
      final thisMonth = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(preset: 'month'),
        now: today,
      );

      // September 2026 holds: elec (due 09-15), water (due 09-15), wifi (due
      // 09-05 — overdue, but filed under its DUE date) and paid-one (paid
      // 09-05). Nothing here is outside September, so the membership is the
      // assertion — ties make the order non-deterministic, not the contents.
      expect(thisMonth, hasLength(4));
      expect(thisMonth.map((e) => e.billId).toSet(), {
        'elec',
        'water',
        'wifi',
        'paid-one',
      });
    });

    test('8a. a preset excludes a row filed outside it', () {
      final entries = buildBillHistoryEntries(
        bills: [
          bill(billId: 'august', dueInDays: -20), // 2026-08-21
          bill(billId: 'september'), // 2026-09-15
        ],
        events: const [],
        now: today,
      );

      final thisMonth = applyBillHistoryFilters(
        entries,
        const BillHistoryFilters(preset: 'month'),
        now: today,
      );

      expect(thisMonth.map((e) => e.billId), ['september']);
    });

    test('8b. "Today" selects only rows filed under today', () {
      final entries = buildBillHistoryEntries(
        bills: [
          bill(billId: 'due-today', dueInDays: 0),
          bill(billId: 'due-tomorrow', dueInDays: 1),
          bill(billId: 'paid-today', isPaid: true, dueInDays: -40),
        ],
        events: [paid(refId: 'paid-today', date: today)],
        now: today,
      );

      final result = applyBillHistoryFilters(
        entries,
        const BillHistoryFilters(preset: 'today'),
        now: today,
      );

      expect(result.map((e) => e.billId), ['due-today', 'paid-today']);
    });

    test('8c. a Paid bill is selected by its payment date, an Upcoming bill by '
        'its due date — the documented split', () {
      final entries = buildBillHistoryEntries(
        bills: [
          // Due in September, but PAID in August.
          bill(billId: 'paid-in-aug', isPaid: true, dueInDays: 20),
          bill(billId: 'due-in-sep', dueInDays: 20),
        ],
        events: [paid(refId: 'paid-in-aug', date: DateTime(2026, 8, 20))],
        now: today,
      );

      final august = applyBillHistoryFilters(
        entries,
        const BillHistoryFilters(preset: 'lastmonth'),
        now: today,
      );
      expect(august.map((e) => e.billId), ['paid-in-aug']);

      final september = applyBillHistoryFilters(
        entries,
        const BillHistoryFilters(preset: 'month'),
        now: today,
      );
      expect(september.map((e) => e.billId), ['due-in-sep']);
    });

    test('9. a custom range uses the shared half-open boundary convention', () {
      final entries = buildBillHistoryEntries(
        bills: [
          bill(billId: 'before', dueInDays: -1), // 2026-09-09
          bill(billId: 'start', dueInDays: 0), // 2026-09-10
          bill(billId: 'inside'), // 2026-09-15
        ],
        events: const [],
        now: today,
      );

      final result = applyBillHistoryFilters(
        entries,
        BillHistoryFilters(
          preset: FilterPeriods.custom,
          range: DateTimeRange(
            start: DateTime(2026, 9, 10),
            end: DateTime(2026, 9, 16),
          ),
        ),
        now: today,
      );

      // start is included; the day before is not.
      expect(result.map((e) => e.billId), ['inside', 'start']);
    });

    test('9b. the custom range\'s END is exclusive — a row exactly on it is '
        'out', () {
      final entries = buildBillHistoryEntries(
        bills: [bill(billId: 'on-end', dueInDays: 6)], // 2026-09-16
        events: const [],
        now: today,
      );

      final result = applyBillHistoryFilters(
        entries,
        BillHistoryFilters(
          preset: FilterPeriods.custom,
          range: DateTimeRange(
            start: DateTime(2026, 9, 10),
            end: DateTime(2026, 9, 16),
          ),
        ),
        now: today,
      );

      expect(result, isEmpty);
    });

    test('filters combine — they intersect, they do not union', () {
      final result = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(
          categoryId: 'utilities',
          statuses: {BillHistoryStatus.upcoming},
        ),
        now: today,
      );

      expect(result.map((e) => e.billId), ['elec', 'water']);
    });

    test('a filter combination matching nothing returns empty, not everything',
        () {
      final result = applyBillHistoryFilters(
        build(),
        const BillHistoryFilters(
          categoryId: 'rental',
          statuses: {BillHistoryStatus.upcoming},
        ),
        now: today,
      );

      expect(result, isEmpty);
    });
  });

  group('BillHistoryFilters — reporting what is active', () {
    test('an empty filter set reports itself as empty', () {
      expect(const BillHistoryFilters().isEmpty, isTrue);
      expect(const BillHistoryFilters().activeCount, 0);
    });

    test('blank search is not an active filter', () {
      expect(const BillHistoryFilters(searchQuery: '  ').isEmpty, isTrue);
    });

    test('each populated filter counts once', () {
      expect(
        const BillHistoryFilters(
          statuses: {BillHistoryStatus.paid},
          categoryId: 'rental',
          memberUserId: 'u1',
          preset: '30d',
          searchQuery: 'rent',
        ).activeCount,
        5,
      );
    });

    test('a custom range counts as one period filter, not two', () {
      expect(
        BillHistoryFilters(
          preset: FilterPeriods.custom,
          range: DateTimeRange(
            start: DateTime(2026, 9, 2),
            end: DateTime(2026, 10, 3),
          ),
        ).activeCount,
        1,
      );
    });
  });

  group('BillHistoryStatus', () {
    test('every status has a stable key and a distinct label', () {
      expect(BillHistoryStatus.values.map((s) => s.key), [
        'paid',
        'overdue',
        'upcoming',
      ]);
      expect(BillHistoryStatus.values.map((s) => s.label), [
        'Paid',
        'Overdue',
        'Upcoming',
      ]);
    });

    test('the vocabulary is bills-specific — no expense milestone words', () {
      const expenseWords = {'Pending', 'Approved', 'Rejected'};
      for (final status in BillHistoryStatus.values) {
        expect(expenseWords, isNot(contains(status.label)));
      }
    });

    test('a key round-trips, and an unknown key is null', () {
      expect(
        BillHistoryStatus.fromKey('overdue'),
        BillHistoryStatus.overdue,
      );
      expect(BillHistoryStatus.fromKey('nonsense'), isNull);
    });
  });
}
