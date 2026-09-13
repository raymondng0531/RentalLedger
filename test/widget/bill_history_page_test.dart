import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_ledger/core/errors/failures.dart';
import 'package:rental_ledger/core/utils/failure_messages.dart';
import 'package:rental_ledger/core/widgets/skeleton.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/history/presentation/pages/bill_history_page.dart';
import 'package:rental_ledger/features/history/presentation/providers/bill_history_provider.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';
import 'package:rental_ledger/features/history/presentation/utils/bill_history.dart';
import 'package:rental_ledger/features/history/presentation/widgets/filter_widgets.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Page-level cover for Bill History: the month grouping it reuses from
/// History, its filter sheet, its three async states, its drill-through to the
/// existing Bill Details route, and its behaviour across the responsive width
/// sweep.
///
/// The pure rules (status derivation, the bill→payment join, every filter
/// predicate) are covered far more cheaply in `test/unit/bill_history_test.dart`
/// — this file only asserts what needs a rendered widget.
///
/// Statuses are FROZEN: entries are built once with an injected `now`, and the
/// page's provider is overridden with the result, so nothing here depends on
/// the wall clock. Every date used is either comfortably past or comfortably
/// future, so the fixtures stay valid whenever the suite is run.

// ── Fixtures ────────────────────────────────────────────────────────

final _now = DateTime(2026, 9, 10);

// The 'internet' category is named "Broadband", not "Internet": a category
// name identical to a bill title would make every `find.text` in this file
// ambiguous, and the collision would be an artefact of the fixture rather than
// of the page.
const _categories = <CategoryEntity>[
  CategoryEntity(categoryId: 'utilities', name: 'Utilities', icon: 'bolt'),
  CategoryEntity(categoryId: 'internet', name: 'Broadband', icon: 'wifi'),
];

final _members = <HouseMemberEntity>[
  HouseMemberEntity(
    memberId: 'm1',
    houseId: 'h1',
    userId: 'u-treasurer',
    role: 'Treasurer',
    joinedAt: DateTime(2026),
    displayName: 'Bob',
  ),
  HouseMemberEntity(
    memberId: 'm2',
    houseId: 'h1',
    userId: 'u-member',
    joinedAt: DateTime(2026),
    displayName: 'Alice',
  ),
];

BillEntity _bill({
  required String billId,
  required String title,
  double? amount,
  required DateTime dueDate,
  String categoryId = 'utilities',
  bool isPaid = false,
}) {
  return BillEntity(
    billId: billId,
    houseId: 'h1',
    title: title,
    amount: amount,
    dueDate: dueDate,
    categoryId: categoryId,
    isPaid: isPaid,
    createdAt: DateTime(2026),
  );
}

HistoryEvent _payment({
  required String transactionId,
  required String refId,
  required String title,
  required DateTime date,
  double amount = -120,
  String? paymentMethod,
  String? periodLabel,
  String? receiptUrl,
  String userId = 'u-treasurer',
}) {
  return HistoryEvent(
    id: 'bill-paid-$transactionId',
    type: HistoryEventType.billPaid,
    refId: refId,
    title: title,
    amount: amount,
    date: date,
    userId: userId,
    paymentMethod: paymentMethod,
    periodLabel: periodLabel,
    receiptUrl: receiptUrl,
  );
}

/// Bills + payments that between them exercise every state the page renders.
///
/// * **Internet** — amount-bearing, not paid, due in the future → Upcoming.
/// * **Electricity** — amount-bearing, paid TWICE (the recurring case: one
///   billId, two settlements), with method / period / receipt → Paid.
/// * **Cleaning Roster** — NO amount, paid with no payment record at all
///   (settling an amountless bill writes no transaction) → Paid, "Reminder".
/// * **Water** — amount-bearing, not paid, due in the past → Overdue.
List<BillHistoryEntry> _entries() {
  return buildBillHistoryEntries(
    bills: [
      _bill(
        billId: 'bill-wifi',
        title: 'Internet',
        amount: 150,
        dueDate: DateTime(2026, 12),
        categoryId: 'internet',
      ),
      _bill(
        billId: 'bill-util',
        title: 'Electricity',
        amount: 120,
        dueDate: DateTime(2026, 8, 20),
        isPaid: true,
      ),
      _bill(
        billId: 'bill-reminder',
        title: 'Cleaning Roster',
        dueDate: DateTime(2026, 8, 5),
        isPaid: true,
      ),
      _bill(
        billId: 'bill-water',
        title: 'Water',
        amount: 80,
        dueDate: DateTime(2026, 8),
      ),
    ],
    events: [
      _payment(
        transactionId: 'tx-1',
        refId: 'bill-util',
        title: 'Electricity',
        date: DateTime(2026, 8, 6, 17, 3),
        paymentMethod: 'Bank Transfer',
        periodLabel: '2026-08',
        receiptUrl: 'https://example.com/receipt.jpg',
      ),
      _payment(
        transactionId: 'tx-2',
        refId: 'bill-util',
        title: 'Electricity',
        date: DateTime(2026, 7, 6, 9, 15),
        paymentMethod: 'Cash',
        periodLabel: '2026-07',
      ),
    ],
    now: _now,
  );
}

// ── Harness ─────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  AsyncValue<List<BillHistoryEntry>>? state,
  List<Override> extra = const [],
  Size size = const Size(420, 1400),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A null [state] leaves the REAL composed provider in place, so a test
        // can drive its two sources instead and exercise the join itself.
        if (state != null) billHistoryProvider.overrideWithValue(state),
        categoriesProvider.overrideWith((ref) => _categories),
        allMembersStreamProvider.overrideWith((ref) => Stream.value(_members)),
        ...extra,
      ],
      // Mirrors `app.dart`: the page's error state renders the shared
      // ErrorDisplay, whose retry button is localized.
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BillHistoryPage(),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // The loading state renders the shared shimmer, whose animation repeats
    // forever — pumpAndSettle would never return.
    await tester.pump();
    await tester.pump();
  }
}

/// Pumps the page in its populated data state.
Future<void> _pumpData(
  WidgetTester tester, {
  List<Override> extra = const [],
  List<BillHistoryEntry>? entries,
  Size size = const Size(420, 1400),
}) {
  return _pump(
    tester,
    state: AsyncValue.data(entries ?? _entries()),
    extra: extra,
    size: size,
  );
}

// ── Filter-sheet interaction ────────────────────────────────────────

Finder _section(String label) =>
    find.byWidgetPredicate((w) => w is FilterSection && w.label == label);

/// The option tile labelled [label] inside [section]. The sheet renders several
/// "All" tiles (Status and the member section each have one), so an unscoped
/// finder is ambiguous.
Finder _option(String section, String label) => find.descendant(
  of: _section(section),
  matching: find.widgetWithText(FilterSelectableOption, label),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Filters'));
  await tester.pumpAndSettle();
}

Future<void> _tapOption(
  WidgetTester tester,
  String section,
  String label,
) async {
  final finder = _option(section, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

/// The month headers currently rendered, in order.
List<String> _monthHeaders(WidgetTester tester) {
  const months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where((s) => months.any((m) => s.startsWith('$m ')))
      .toList();
}

/// The bill titles currently rendered, in row order.
List<String> _rowTitles(WidgetTester tester, List<String> titles) {
  final found = <(int, String)>[];
  for (final title in titles) {
    final finder = find.text(title);
    if (finder.evaluate().isEmpty) continue;
    found.add((tester.getTopLeft(finder.first).dy.round(), title));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found) f.$2];
}

const _allTitles = ['Internet', 'Electricity', 'Cleaning Roster', 'Water'];

void main() {
  group('Bill History — rows', () {
    testWidgets('renders every bill the house can see', (tester) async {
      await _pumpData(tester);

      for (final title in _allTitles) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('files each row under its own date, newest first', (
      tester,
    ) async {
      await _pumpData(tester);

      // Newest-first by the date each row is filed under: the upcoming bill's
      // due date (Dec) leads, then the paid bill's PAYMENT date (6 Aug), then
      // the amountless bill's due date (5 Aug), then the overdue due date.
      expect(_rowTitles(tester, _allTitles), [
        'Internet',
        'Electricity',
        'Cleaning Roster',
        'Water',
      ]);
    });

    testWidgets('groups rows into calendar months, newest month first', (
      tester,
    ) async {
      await _pumpData(tester);

      expect(_monthHeaders(tester), ['DECEMBER 2026', 'AUGUST 2026']);
    });

    testWidgets('states an amountless bill as "Reminder", not RM 0.00', (
      tester,
    ) async {
      await _pumpData(tester);

      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('RM 0.00'), findsNothing);
      // The amount-bearing rows still show their amounts.
      expect(find.textContaining('150.00'), findsWidgets);
    });

    testWidgets('shows the derived status as a bill-vocabulary chip', (
      tester,
    ) async {
      await _pumpData(tester);

      // Upcoming / Paid / Overdue — never the expense words.
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      // Electricity and Cleaning Roster are both settled.
      expect(find.text('Paid'), findsNWidgets(2));
      for (final word in ['Pending', 'Approved', 'Rejected']) {
        expect(find.text(word), findsNothing, reason: word);
      }
    });

    testWidgets('attaches the recorded payment details to a paid bill', (
      tester,
    ) async {
      await _pumpData(tester);

      // Method, covered month and a receipt affordance from the billPaid event.
      expect(find.text('Bank Transfer'), findsOneWidget);
      expect(find.text('Covers 2026-08'), findsOneWidget);
      expect(find.text('Receipt'), findsOneWidget);
      // The recorder, resolved to a name — never a UID.
      expect(find.textContaining('Bob'), findsWidgets);
      expect(find.textContaining('u-treasurer'), findsNothing);
    });

    testWidgets('surfaces that a bill holds more than one payment', (
      tester,
    ) async {
      await _pumpData(tester);

      // Electricity was settled twice (the recurring-bill shape: one billId).
      // Without the count the row would read as a single settlement.
      expect(find.text('2 payments'), findsOneWidget);
      expect(find.text('1 payments'), findsNothing);
    });

    testWidgets('a bill with no recorded payment shows no payment chips', (
      tester,
    ) async {
      await _pumpData(tester);

      // Water is unpaid, Cleaning Roster settled with no transaction: neither
      // has a method, a covered month, or a receipt.
      final waterCard = find.ancestor(
        of: find.text('Water'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: waterCard, matching: find.text('Receipt')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: waterCard,
          matching: find.textContaining('Covers '),
        ),
        findsNothing,
      );
    });
  });

  group('Bill History — async states', () {
    testWidgets('loading shows the shared shimmer skeleton', (tester) async {
      await _pump(tester, state: const AsyncValue.loading(), settle: false);

      expect(find.byType(SkeletonListBody), findsOneWidget);
      expect(find.text('Internet'), findsNothing);
    });

    testWidgets('error shows the failure message and a retry', (tester) async {
      // A coded failure is described by its code, so the member reads the
      // sentence that code stands for — never the English the data layer put
      // in the exception for a developer.
      await _pump(
        tester,
        state: const AsyncValue.error(
          FirebaseFailure('Could not load bill history.',
              code: FailureCodes.loadFailed),
          StackTrace.empty,
        ),
      );

      expect(find.text('We could not load this. Please try again.'),
          findsOneWidget);
      expect(find.text('Could not load bill history.'), findsNothing);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('a failure in EITHER source fails the page', (tester) async {
      // The real composed provider is left in place here: this asserts the join
      // the page actually depends on, not a stubbed value.
      await _pump(
        tester,
        // No billHistoryProvider override — the sources below feed it.
        extra: [
          billsProvider.overrideWith((ref) => Stream.value(const <BillEntity>[])),
          historyProvider.overrideWith(
            (ref, key) => Stream.error(const FirebaseFailure('Could not load.')),
          ),
        ],
      );

      // The failure carries no code, so there is no sentence of its own to
      // show. The page must still fail loudly and in the reader's language —
      // it may not fall through to the empty state, and it may not leak the
      // raw `Could not load.` the data layer wrote for a log.
      expect(find.text('Could not load.'), findsNothing);
      expect(find.text('Something went wrong. Please try again.'),
          findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('retry re-runs BOTH sources the page is derived from', (
      tester,
    ) async {
      var billReads = 0;
      var eventReads = 0;

      await _pump(
        tester,
        extra: [
          billsProvider.overrideWith((ref) {
            billReads++;
            return Stream.value(const <BillEntity>[]);
          }),
          historyProvider.overrideWith((ref, key) {
            eventReads++;
            return Stream.error(const FirebaseFailure('Could not load.'));
          }),
        ],
      );

      expect(billReads, 1);
      expect(eventReads, 1);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Invalidating the derived provider alone would re-run its build body but
      // reuse the sources' cached error, so the retry must reach the sources.
      expect(billReads, 2);
      expect(eventReads, 2);
    });

    testWidgets('an empty house reads as "no bills yet", not "no results"', (
      tester,
    ) async {
      await _pumpData(tester, entries: const []);

      expect(find.text('No bills yet'), findsOneWidget);
      expect(find.text('No results found'), findsNothing);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('filters matching nothing read as "no results found"', (
      tester,
    ) async {
      await _pumpData(tester);

      await tester.enterText(find.byType(TextField), 'nonexistent bill');
      await tester.pumpAndSettle();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('No bills yet'), findsNothing);
    });
  });

  group('Bill History — search and filters', () {
    testWidgets('search matches the bill title, case-insensitively', (
      tester,
    ) async {
      await _pumpData(tester);

      await tester.enterText(find.byType(TextField), 'WATER');
      await tester.pumpAndSettle();

      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Electricity'), findsNothing);
      // The active search is summarised and clearable.
      expect(find.text('"water"'), findsOneWidget);
    });

    testWidgets('the search is cleared by "Clear all"', (tester) async {
      await _pumpData(tester);

      await tester.enterText(find.byType(TextField), 'water');
      await tester.pumpAndSettle();
      expect(find.text('Electricity'), findsNothing);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('the status filter keeps only the chosen statuses', (
      tester,
    ) async {
      await _pumpData(tester);

      await _openSheet(tester);
      await _tapOption(tester, 'Status', 'Upcoming');
      await _apply(tester);

      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Electricity'), findsNothing);
      expect(find.text('Water'), findsNothing);
      // The choice is summarised as a removable chip.
      expect(find.text('Upcoming'), findsNWidgets(2)); // chip + row status
    });

    testWidgets('several statuses can be selected at once', (tester) async {
      await _pumpData(tester);

      await _openSheet(tester);
      await _tapOption(tester, 'Status', 'Overdue');
      await _tapOption(tester, 'Status', 'Upcoming');
      await _apply(tester);

      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Electricity'), findsNothing);
    });

    testWidgets('the category filter keeps only that category', (tester) async {
      await _pumpData(tester);

      await _openSheet(tester);
      await tester.tap(find.text('All Categories').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Broadband').last);
      await tester.pumpAndSettle();
      await _apply(tester);

      // Only the Internet bill is in the 'internet' category.
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Electricity'), findsNothing);
      expect(find.text('Water'), findsNothing);
      expect(find.text('Category: Broadband'), findsOneWidget);
    });

    testWidgets('the period filter selects a paid row by its payment date', (
      tester,
    ) async {
      await _pumpData(tester);

      await _openSheet(tester);
      // "This Month" is September 2026; Electricity was paid in August, so it
      // is only kept if the range matched the DUE date instead.
      await _tapOption(tester, 'Period', 'This Month');
      await _apply(tester);

      expect(find.text('No results found'), findsOneWidget);
    });
  });

  group('Bill History — the member ("Recorded by") filter', () {
    testWidgets('selects bills by who recorded the payment', (tester) async {
      await _pumpData(tester);

      await _openSheet(tester);
      await _tapOption(tester, 'Recorded by', 'Bob');
      await _apply(tester);

      // Bob recorded both Electricity payments, so only that bill survives.
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Water'), findsNothing);
      expect(find.text('Cleaning Roster'), findsNothing);
      expect(find.text('Internet'), findsNothing);
      expect(find.text('Recorded by: Bob'), findsOneWidget);
    });

    testWidgets('a member who recorded nothing matches no bill', (tester) async {
      await _pumpData(tester);

      await _openSheet(tester);
      await _tapOption(tester, 'Recorded by', 'Alice');
      await _apply(tester);

      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets(
      'excludes rows with no recorder instead of attributing one to them',
      (tester) async {
        // A bill has no member attribution at all: the only member fact in the
        // data is the recorder on a PAYMENT. So an active member filter must
        // drop every row with no recorded payment — the amountless settled bill
        // and every unpaid bill — rather than guess whose they are.
        await _pumpData(tester);

        await _openSheet(tester);
        await _tapOption(tester, 'Recorded by', 'Bob');
        await _apply(tester);

        // Cleaning Roster is PAID but has no payment record, so it is excluded
        // for the same reason the unpaid bills are.
        expect(find.text('Cleaning Roster'), findsNothing);
        expect(find.text('Paid'), findsOneWidget); // only Electricity
      },
    );

    testWidgets('says WHY a member filter can hide a bill', (tester) async {
      await _pumpData(tester);

      await _openSheet(tester);
      await _tapOption(tester, 'Recorded by', 'Alice');
      await _apply(tester);

      // Not the generic "try adjusting your filters": the emptiness is
      // structural, and the user is told the structural reason.
      expect(
        find.textContaining('only when a payment was recorded'),
        findsOneWidget,
      );
    });
  });

  group('Bill History — navigation', () {
    /// A router with the real Bill Details path shape, so the pushed route and
    /// its billId can be asserted.
    Future<void> pumpRouted(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/bill-history',
        routes: [
          GoRoute(
            path: '/bill-history',
            builder: (_, __) => const BillHistoryPage(),
          ),
          GoRoute(
            path: '/bill-details/:billId',
            // A stand-in for the existing Bill Details page: it only needs the
            // path shape, an AppBar (for the automatic back button) and the id
            // it was handed.
            builder:
                (_, state) => Scaffold(
                  appBar: AppBar(
                    title: Text('DETAILS ${state.pathParameters['billId']}'),
                  ),
                ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billHistoryProvider.overrideWithValue(AsyncValue.data(_entries())),
            categoriesProvider.overrideWith((ref) => _categories),
            allMembersStreamProvider.overrideWith(
              (ref) => Stream.value(_members),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a row opens that bill\'s detail route', (
      tester,
    ) async {
      await pumpRouted(tester);

      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();

      // The existing Bill Details route, carrying the bill's own id.
      expect(find.text('DETAILS bill-water'), findsOneWidget);
    });

    testWidgets('Bill Details can be backed out of, returning to the list', (
      tester,
    ) async {
      await pumpRouted(tester);

      await tester.tap(find.text('Electricity'));
      await tester.pumpAndSettle();
      expect(find.text('DETAILS bill-util'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Bill History'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
    });

    testWidgets('the receipt chip opens the shared full-screen viewer', (
      tester,
    ) async {
      await pumpRouted(tester);

      await tester.tap(find.text('Receipt'));
      await tester.pumpAndSettle();

      // Not the bill detail route — a pushed route of its own.
      expect(find.text('DETAILS bill-util'), findsNothing);
      expect(find.text('Receipt / Proof'), findsOneWidget);
    });
  });

  group('Bill History — responsive width sweep', () {
    // The widths the Web/PWA responsive work targets: compact (360, 414),
    // medium (600, 768, 834), expanded (840, 1024), extraLarge (1280, 1440,
    // 1920) — the breakpoints sit at 600/840/1200.
    const widths = <double>[360, 414, 600, 768, 834, 840, 1024, 1280, 1440, 1920];

    for (final width in widths) {
      testWidgets('renders without overflow at ${width}px', (tester) async {
        // Tall enough that every row is laid out, so a deep overflow is caught.
        await _pumpData(tester, size: Size(width, 3000));

        expect(
          tester.takeException(),
          isNull,
          reason: 'Bill History overflowed at $width px',
        );
        expect(find.text('Internet'), findsOneWidget);
        expect(find.text('Cleaning Roster'), findsOneWidget);
      });
    }

    testWidgets('the widest and narrowest layouts keep the same rows', (
      tester,
    ) async {
      await _pumpData(tester, size: const Size(360, 3000));
      final narrow = _rowTitles(tester, _allTitles);

      await _pumpData(tester, size: const Size(1920, 3000));
      final wide = _rowTitles(tester, _allTitles);

      expect(narrow, wide);
      expect(narrow, hasLength(4));
    });
  });
}
