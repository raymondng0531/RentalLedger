import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_colors.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/widgets/receipt_viewer.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/widgets/category_picker.dart';
import 'package:rental_ledger/features/expenses/presentation/widgets/expense_card.dart';
import 'package:rental_ledger/features/expenses/presentation/widgets/payment_method_chips.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 3C — Expenses.
///
/// Three different kinds of claim are being proved here:
///
/// 1. **Parity.** Every colour Phase 3C replaced in light mode resolves to the
///    exact ARGB value V1.0 shipped — asserted against the legacy `AppTheme`
///    constant the old call site read, so a future palette edit cannot silently
///    re-colour the shipped light theme.
/// 2. **Dark legibility.** The same widgets, pumped over `AppTheme.darkTheme`,
///    paint foregrounds that clear WCAG AA against what they actually sit on —
///    including the composited fills (a chip's 16/22-alpha wash over the card),
///    not just the raw token.
/// 3. **Deliberate non-migrations.** The colours Phase 3C chose to LEAVE are
///    pinned too, so "we decided this is correct" is enforced rather than
///    remembered: the receipt viewer's fixed black ground, the stored category
///    dot, and the two literals with no palette token behind them.
///
/// Widgets are pumped through the real theme pair rather than a bare
/// `MaterialApp`, so `context.colors` resolves through `ThemeData.extensions`
/// exactly as it does in the app.
///
/// Where a shipped V1.0 pairing falls short of AA, the test asserts the
/// *shortfall itself* rather than quietly lowering the bar: light mode is frozen
/// this phase, so the honest claim is "unchanged, and dark is better". Those
/// ratios are surfaced in the Phase 3C audit as recommendations.

/// WCAG contrast ratio: `(lighter + 0.05) / (darker + 0.05)`.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// What a translucent fill actually looks like once painted over its ground.
Color _over(Color fill, Color ground) => Color.alphaBlend(fill, ground);

/// `MaterialApp` swaps themes through an `AnimatedTheme`, so re-pumping the
/// same element in the other mode leaves the *old* palette on screen until the
/// cross-fade finishes. These tests switch modes inside a single test, so the
/// animation has to be run out before anything is asserted — and
/// `pumpAndSettle` is unusable here because several of these widgets contain
/// indefinitely-repeating animations.
///
/// The localization delegates mirror `app.dart`: the receipt viewer resolves a
/// localized default title.
Future<void> _pump(WidgetTester tester, Widget child, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// For widgets that build their own `Scaffold` (the receipt viewer) — wrapping
/// one in another `Scaffold` would make the background finder ambiguous.
Future<void> _pumpBare(
  WidgetTester tester,
  Widget child,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const double _aa = 4.5;

// ── ExpenseCard helpers ──

ExpenseEntity _expense({
  String status = 'pending',
  String paymentSource = 'central',
}) => ExpenseEntity(
  expenseId: 'e1',
  houseId: 'h1',
  purchasedBy: 'u1',
  title: 'Laundry Detergent',
  categoryId: 'household',
  amount: 42.5,
  paymentSource: paymentSource,
  status: status,
  createdAt: DateTime(2026, 9, 12, 14, 30),
);

Future<void> _pumpCard(
  WidgetTester tester,
  ExpenseEntity expense,
  ThemeData theme,
) => _pump(
  tester,
  ExpenseCard(
    expense: expense,
    categoryName: 'Household',
    memberName: 'Ahmad',
  ),
  theme,
);

Color _cardFill(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card)).color!;

/// The colour a `Text` paints itself with (chips, subtitle).
Color _inkOf(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

/// The amount line. It is the only text on the card that can carry a sign, so
/// the caller names the exact string rather than the test guessing at it.
Color _amountInk(WidgetTester tester, String amount) =>
    tester.widget<Text>(find.text(amount)).style!.color!;

// ── CategoryPicker helpers ──

BoxDecoration _categoryChipFill(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

Color _categoryChipInk(WidgetTester tester, String label) => tester
    .widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    )
    .style
    .color!;

/// The category-identity dot — the only circular `Container` in the picker.
Color _categoryDot(WidgetTester tester) {
  final dot = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );
  return (tester.widget<Container>(dot.first).decoration! as BoxDecoration)
      .color!;
}

void main() {
  // ──────────────────────────────────────────────
  // Parity ledger — the values V1.0 actually shipped
  // ──────────────────────────────────────────────
  //
  // Phase 3C's rule is that a migration may not move light mode. These pin
  // each substituted token against the legacy `AppTheme` constant the old call
  // site read, so the guarantee survives a palette edit.
  group('Phase 3C parity ledger', () {
    test('every substituted token equals the V1.0 constant it replaced', () {
      // Surfaces — Scaffold/AppBar `Colors.white`, and the muted card fill
      // that used to read `AppTheme.backgroundLight`.
      expect(AppColors.light.surface, AppTheme.surfaceWhite);
      expect(AppColors.light.surfaceMuted, AppTheme.backgroundLight);

      // Text.
      expect(AppColors.light.textPrimary, AppTheme.textPrimary);
      expect(AppColors.light.textSecondary, AppTheme.textSecondary);

      // Lines.
      expect(AppColors.light.divider, AppTheme.dividerColor);

      // Brand + semantics.
      expect(AppColors.light.primary, AppTheme.primaryGreen);
      expect(AppColors.light.error, AppTheme.errorRed);
      expect(AppColors.light.success, AppTheme.successGreen);
      expect(AppColors.light.statusPending, AppTheme.statusPending);
      expect(AppColors.light.statusApproved, AppTheme.statusApproved);
      expect(
        AppColors.light.statusDirectPayment,
        AppTheme.statusDirectPayment,
      );
    });

    test('the grey literals had exact token equivalents', () {
      // `Colors.grey` is 0xFF9E9E9E, which is both `textHint` and
      // `placeholderTint` in light mode — so the receipt placeholder panel, its
      // caption, and the `Colors.grey` fallbacks in the detail pages all kept
      // their shipped value. Compared as ARGB rather than by `==` because
      // `Colors.grey` is a `MaterialColor` and the tokens are plain `Color`s.
      expect(AppColors.light.textHint.toARGB32(), 0xFF9E9E9E);
      expect(AppColors.light.placeholderTint.toARGB32(), 0xFF9E9E9E);
      expect(Colors.grey.toARGB32(), 0xFF9E9E9E);
    });

    test('onPrimary reproduces the white the buttons shipped', () {
      // Every FilledButton spinner, the selected chip label and the tab pill
      // label were literal `Colors.white`. `onPrimary` has to reproduce that
      // byte for byte or light mode moves.
      expect(AppColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(Colors.white.toARGB32(), 0xFFFFFFFF);
    });

    test('no token represents the two literals Phase 3C left alone', () {
      // Everything here compares ARGB, not `Color` instances: `Color.==` is
      // runtimeType-sensitive, and `Colors.blue` / `Colors.grey` /
      // `Colors.white` are `MaterialColor`s while the palette tokens are plain
      // `Color`s — so an `==` assertion would pass or fail on the type, not on
      // the value it is supposed to be pinning.

      // Why `Colors.blue` (the payment-source info banner) was NOT migrated:
      // the palette's only blue is `statusApproved`, which is a *status* role.
      // Borrowing it for a non-status banner would tie the banner's colour to
      // the approval palette, and there is no informational token to use.
      expect(Colors.blue.toARGB32(), AppColors.light.statusApproved.toARGB32());
      expect(
        [
          AppColors.light.primary,
          AppColors.light.error,
          AppColors.light.success,
          AppColors.light.statusPending,
          AppColors.light.statusPaid,
          AppColors.light.statusDirectPayment,
        ].map((c) => c.toARGB32()),
        isNot(contains(Colors.blue.toARGB32())),
        reason: 'no other token is the banner blue',
      );

      // Why `Colors.redAccent` (receipt debug text) was NOT migrated: no token
      // carries #FF5252, so any substitution would move shipped light mode.
      expect(
        Colors.redAccent.toARGB32(),
        isNot(AppColors.light.error.toARGB32()),
      );
      expect(
        [
          AppColors.light.error,
          AppColors.light.statusRejected,
        ].map((c) => c.toARGB32()),
        isNot(contains(Colors.redAccent.toARGB32())),
        reason: 'no error/red token is redAccent',
      );
    });
  });

  // ──────────────────────────────────────────────
  // ExpenseCard
  // ──────────────────────────────────────────────
  group('ExpenseCard', () {
    testWidgets('light mode is byte-identical to V1.0', (tester) async {
      await _pumpCard(tester, _expense(), AppTheme.lightTheme);

      expect(_cardFill(tester), AppTheme.backgroundLight);
      expect(_inkOf(tester, 'Submitted'), AppTheme.statusPending);
      expect(_inkOf(tester, 'Central Account'), AppTheme.statusApproved);
      expect(_inkOf(tester, 'Household'), AppTheme.textSecondary);
      expect(_amountInk(tester, 'RM 42.50'), AppTheme.textSecondary);
    });

    testWidgets('light mode keeps every shipped per-status ink', (
      tester,
    ) async {
      const expected = {
        'pending': AppTheme.statusPending,
        'approved': AppTheme.statusApproved,
        'rejected': AppTheme.errorRed,
        'paid': AppTheme.successGreen,
      };
      const labels = {
        'pending': 'Submitted',
        'approved': 'Approved',
        'rejected': 'Rejected',
        'paid': 'Paid',
      };

      for (final entry in expected.entries) {
        await _pumpCard(
          tester,
          _expense(status: entry.key),
          AppTheme.lightTheme,
        );
        expect(
          _inkOf(tester, labels[entry.key]!),
          entry.value,
          reason: 'light-mode ${entry.key} chip moved',
        );
      }
    });

    testWidgets('dark mode lifts the card off the page', (tester) async {
      await _pumpCard(tester, _expense(), AppTheme.darkTheme);

      expect(_cardFill(tester), AppColors.dark.surfaceMuted);
      expect(
        _cardFill(tester),
        isNot(Colors.white),
        reason: 'a white card in dark mode is the bug being fixed',
      );
      expect(_inkOf(tester, 'Household'), AppColors.dark.textSecondary);
    });

    testWidgets('dark statuses stay distinct from each other and readable', (
      tester,
    ) async {
      const labels = {
        'pending': 'Submitted',
        'approved': 'Approved',
        'rejected': 'Rejected',
        'paid': 'Paid',
      };

      final inks = <Color>[];
      for (final entry in labels.entries) {
        await _pumpCard(
          tester,
          _expense(status: entry.key),
          AppTheme.darkTheme,
        );
        final ink = _inkOf(tester, entry.value);
        inks.add(ink);
        expect(
          _contrast(ink, _cardFill(tester)),
          greaterThanOrEqualTo(_aa),
          reason: 'dark ${entry.key} chip label is unreadable on the card',
        );
      }

      expect(
        inks.toSet(),
        hasLength(4),
        reason:
            'pending / approved / rejected / paid must remain distinguishable',
      );
    });

    testWidgets('the dark paid amount stays legible as money out', (
      tester,
    ) async {
      await _pumpCard(tester, _expense(status: 'paid'), AppTheme.darkTheme);

      final ink = _amountInk(tester, '-RM 42.50');
      expect(ink, AppColors.dark.error);
      expect(
        _contrast(ink, _cardFill(tester)),
        greaterThanOrEqualTo(_aa),
        reason: 'the reimbursed amount is the number the member is watching',
      );
    });

    testWidgets('dark chip ink is readable on its own translucency', (
      tester,
    ) async {
      // The chip is `ink.withAlpha(16)` over the card, with the ink at full
      // strength on top. Composite it rather than trusting the token alone.
      await _pumpCard(tester, _expense(status: 'rejected'), AppTheme.darkTheme);

      final well = _over(AppColors.dark.error.withAlpha(16), _cardFill(tester));
      expect(_contrast(AppColors.dark.error, well), greaterThanOrEqualTo(_aa));
    });
  });

  // ──────────────────────────────────────────────
  // CategoryPicker
  // ──────────────────────────────────────────────
  group('CategoryPicker', () {
    const categories = [
      CategoryEntity(categoryId: 'rent', name: 'Rent', color: 0xFF2563EB),
      CategoryEntity(categoryId: 'food', name: 'Food', color: 0xFF16A34A),
    ];

    Widget picker({String? selectedId}) => CategoryPicker(
      categories: categories,
      selectedId: selectedId,
      onSelected: (_) {},
    );

    testWidgets('light mode is byte-identical to V1.0', (tester) async {
      await _pump(tester, picker(), AppTheme.lightTheme);

      final unselected = _categoryChipFill(tester, 'Rent');
      expect(unselected.color, AppTheme.surfaceWhite);
      expect((unselected.border! as Border).top.color, AppTheme.dividerColor);
      expect(_categoryChipInk(tester, 'Rent'), AppTheme.textSecondary);
    });

    testWidgets('light mode keeps the teal selected treatment', (tester) async {
      await _pump(tester, picker(selectedId: 'rent'), AppTheme.lightTheme);

      final selected = _categoryChipFill(tester, 'Rent');
      expect(selected.color, AppTheme.primaryGreen.withAlpha(36));
      expect((selected.border! as Border).top.color, AppTheme.primaryGreen);
      expect(_categoryChipInk(tester, 'Rent'), AppTheme.primaryGreen);
    });

    testWidgets('dark mode stops painting white chips', (tester) async {
      await _pump(tester, picker(selectedId: 'rent'), AppTheme.darkTheme);

      final unselected = _categoryChipFill(tester, 'Food');
      expect(unselected.color, AppColors.dark.surface);
      expect(unselected.color, isNot(Colors.white));
      expect((unselected.border! as Border).top.color, AppColors.dark.divider);
      expect(_categoryChipInk(tester, 'Food'), AppColors.dark.textSecondary);

      final selected = _categoryChipFill(tester, 'Rent');
      expect(selected.color, AppColors.dark.primary.withAlpha(36));
      expect((selected.border! as Border).top.color, AppColors.dark.primary);
    });

    testWidgets('both dark chip states are readable on their own fill', (
      tester,
    ) async {
      await _pump(tester, picker(selectedId: 'rent'), AppTheme.darkTheme);

      // Unselected: muted ink on the opaque chip surface.
      expect(
        _contrast(
          _categoryChipInk(tester, 'Food'),
          _categoryChipFill(tester, 'Food').color!,
        ),
        greaterThanOrEqualTo(_aa),
      );

      // Selected: teal ink on the teal wash over the page behind it.
      final selectedWell = _over(
        AppColors.dark.primary.withAlpha(36),
        AppColors.dark.background,
      );
      expect(
        _contrast(_categoryChipInk(tester, 'Rent'), selectedWell),
        greaterThanOrEqualTo(_aa),
      );
    });

    testWidgets('the stored category colour is untouched in both modes', (
      tester,
    ) async {
      // Rule 5: category colours live in Firestore. The identity dot paints the
      // stored value verbatim in either mode — no display-time rewriting — so
      // the dot always agrees with the same category on the detail pages.
      await _pump(tester, picker(), AppTheme.lightTheme);
      expect(_categoryDot(tester).toARGB32(), 0xFF2563EB);

      await _pump(tester, picker(), AppTheme.darkTheme);
      expect(_categoryDot(tester).toARGB32(), 0xFF2563EB);
    });
  });

  // ──────────────────────────────────────────────
  // PaymentMethodChips
  // ──────────────────────────────────────────────
  group('PaymentMethodChips', () {
    ChoiceChip chip(WidgetTester tester, String label) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

    Widget chips({String? selected}) =>
        PaymentMethodChips(selected: selected, onSelected: (_) {});

    testWidgets('light mode is byte-identical to V1.0', (tester) async {
      await _pump(tester, chips(), AppTheme.lightTheme);

      final cash = chip(tester, 'Cash');
      expect(cash.selectedColor, AppTheme.primaryGreen);
      expect(cash.backgroundColor, AppTheme.surfaceWhite);
      expect(cash.labelStyle!.color, AppTheme.textPrimary);
    });

    testWidgets('light selection keeps white ink on the teal fill', (
      tester,
    ) async {
      await _pump(tester, chips(selected: 'Cash'), AppTheme.lightTheme);

      final cash = chip(tester, 'Cash');
      expect(cash.labelStyle!.color, Colors.white);
      expect(cash.selectedColor, AppTheme.primaryGreen);
    });

    testWidgets('dark selection flips the ink off white', (tester) async {
      await _pump(tester, chips(selected: 'Cash'), AppTheme.darkTheme);

      final cash = chip(tester, 'Cash');
      expect(cash.selectedColor, AppColors.dark.primary);
      expect(cash.labelStyle!.color, AppColors.dark.onPrimary);
      expect(
        cash.labelStyle!.color,
        isNot(Colors.white),
        reason: 'white on the lightened dark teal measures about 1.9:1',
      );
      expect(
        _contrast(cash.labelStyle!.color!, cash.selectedColor!),
        greaterThanOrEqualTo(_aa),
      );
    });

    testWidgets('dark unselected chip is not white', (tester) async {
      await _pump(tester, chips(selected: 'Cash'), AppTheme.darkTheme);

      final card = chip(tester, 'Card');
      expect(card.backgroundColor, AppColors.dark.surface);
      expect(
        _contrast(card.labelStyle!.color!, card.backgroundColor!),
        greaterThanOrEqualTo(_aa),
      );
    });

    testWidgets(
      'the primary-action ink clears AA in dark, and in light is frozen at '
      'the shipped V1.0 pairing',
      (tester) async {
        // `onPrimary` is the ink every FilledButton spinner in Expenses now
        // uses, so this is the pair it renders on. Dark mode was designed to
        // clear AA.
        expect(
          _contrast(AppColors.dark.onPrimary, AppColors.dark.primary),
          greaterThanOrEqualTo(_aa),
        );

        // Light mode cannot be "fixed" here: white-on-#00897B is the shipped
        // V1.0 button treatment and measures ~4.32:1, a hair under AA. Rule 1
        // forbids moving it this phase, so the shortfall is pinned rather than
        // hidden, and is reported as a recommendation.
        final lightRatio = _contrast(
          AppColors.light.onPrimary,
          AppColors.light.primary,
        );
        expect(lightRatio, greaterThan(4.0));
        expect(lightRatio, lessThan(_aa));
      },
    );
  });

  // ──────────────────────────────────────────────
  // ReceiptViewer — the deliberate non-migration
  // ──────────────────────────────────────────────
  group('ReceiptViewer', () {
    Widget viewer() => const ReceiptViewer(image: SizedBox.shrink());

    testWidgets('its ground is black in BOTH modes', (tester) async {
      // A photo lightbox. Theming this would make the same receipt render
      // differently in light and dark mode, and a light ground would glare
      // around a letterboxed photo.
      await _pumpBare(tester, viewer(), AppTheme.lightTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.black,
      );

      await _pumpBare(tester, viewer(), AppTheme.darkTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.black,
      );
    });

    testWidgets('its title ink is white in BOTH modes', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await _pumpBare(tester, viewer(), theme);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.foregroundColor, Colors.white);
        expect(
          _contrast(appBar.foregroundColor!, appBar.backgroundColor!),
          greaterThanOrEqualTo(_aa),
        );
      }
    });

    testWidgets('the themed alternatives would have been invisible', (
      tester,
    ) async {
      // This is WHY the literal is correct here: neither token a mechanical
      // migration would have reached for is legible on this ground.
      expect(_contrast(AppColors.light.textPrimary, Colors.black), lessThan(2));
      expect(_contrast(AppColors.dark.onPrimary, Colors.black), lessThan(2));
      expect(
        _contrast(Colors.white, Colors.black),
        greaterThanOrEqualTo(_aa),
      );
    });
  });

  // ──────────────────────────────────────────────
  // The literals left in place, with the reasoning pinned
  // ──────────────────────────────────────────────
  group('Deliberate literals', () {
    test('the info-banner blue stays readable in both modes', () {
      // `Colors.blue` on the Add Expense payment-source banner. Left literal
      // because the palette has no *informational* accent: the only blue is
      // `statusApproved`, a status role. Readable as it stands, so nothing is
      // hidden and no token is misused.
      expect(
        _contrast(Colors.blue, AppColors.dark.surface),
        greaterThanOrEqualTo(_aa),
      );
      // Light mode keeps the shipped V1.0 pairing (~3.1:1), frozen this phase.
      expect(
        _contrast(Colors.blue, AppColors.light.surface),
        greaterThan(3.0),
      );
    });

    test('the receipt debug ink stays readable in both modes', () {
      // `Colors.redAccent` diagnostics in receipt_image.dart. Developer-facing,
      // only on a genuinely failed image load, and legible in both modes.
      expect(
        _contrast(Colors.redAccent, AppColors.dark.surface),
        greaterThanOrEqualTo(_aa),
      );
      expect(
        _contrast(Colors.redAccent, AppColors.light.surface),
        greaterThan(3.0),
      );
    });

    test('the translucent neutrals are structural, not brand', () {
      // Every `Colors.transparent` in this phase is either "paint no surface
      // tint over my own fill" or "draw no divider" — mode-independent
      // switches, so leaving them literal is correct rather than an omission.
      // None of them may ever stand in for a surface.
      expect(Colors.transparent.toARGB32(), 0x00000000);
      for (final surface in [
        AppColors.light.surface,
        AppColors.light.surfaceMuted,
        AppColors.dark.surface,
        AppColors.dark.surfaceMuted,
      ]) {
        expect(surface, isNot(Colors.transparent));
      }
    });

    test('every `Colors.white54` in Expenses belongs to the lightbox', () {
      // All thirteen occurrences are error placeholders passed *into* a
      // `ReceiptViewer`, which paints its own fixed black ground in both modes
      // — so white is the correct ink and `context.colors` does not apply.
      //
      // Composited, not raw: `computeLuminance()` ignores alpha, so comparing
      // `Colors.white54` directly would report a misleading 21:1. What actually
      // renders is 54%-white over black.
      final glyph = _over(Colors.white54, Colors.black);
      expect(glyph.toARGB32(), 0xFF8A8A8A);
      expect(
        _contrast(glyph, Colors.black),
        greaterThanOrEqualTo(_aa),
        reason: 'the lightbox placeholder glyph must read on its black ground',
      );
    });
  });

  // ──────────────────────────────────────────────
  // Composited dark surfaces — the fixes that are not a plain token swap
  // ──────────────────────────────────────────────
  group('Composited dark surfaces', () {
    test('the reject banner stays readable over its own red wash', () {
      // The rejected-reason panel is `error.withAlpha(12)` on `surfaceMuted`,
      // with an `error.withAlpha(50)` hairline and full-strength `error` ink.
      final well = _over(
        AppColors.dark.error.withAlpha(12),
        AppColors.dark.surfaceMuted,
      );
      expect(_contrast(AppColors.dark.error, well), greaterThanOrEqualTo(_aa));
      expect(
        _contrast(_over(AppColors.dark.error.withAlpha(50), well), well),
        greaterThan(1.15),
        reason: 'the panel border must remain a visible edge',
      );
    });

    test('the receipt placeholder is not worse in dark than in light', () {
      // Pre-existing V1.0 styling: a muted caption at `textHint` on a faint
      // placeholder wash. It is not AA in EITHER mode, and this phase must not
      // redesign it — so the claim pinned here is that dark did not regress it,
      // while the icon (the primary signal) does improve markedly.
      final lightPanel = _over(
        AppColors.light.placeholderTint.withAlpha(20),
        AppColors.light.surfaceMuted,
      );
      final darkPanel = _over(
        AppColors.dark.placeholderTint.withAlpha(20),
        AppColors.dark.surfaceMuted,
      );

      expect(
        _contrast(AppColors.dark.textHint, darkPanel),
        greaterThanOrEqualTo(_contrast(AppColors.light.textHint, lightPanel)),
      );
      expect(
        _contrast(AppColors.dark.placeholderTint, darkPanel),
        greaterThanOrEqualTo(_aa),
      );
    });

    test('the divider stays visible without becoming a line of text', () {
      // "Visible but subtle" — present against both surfaces it separates.
      for (final ground in [
        AppColors.dark.surface,
        AppColors.dark.background,
      ]) {
        expect(_contrast(AppColors.dark.divider, ground), greaterThan(1.15));
        expect(_contrast(AppColors.dark.divider, ground), lessThan(6.0));
      }
    });

    test('the dark form surfaces separate from the page and read on top', () {
      // Form fields and cards in Expenses sit on `surface` / `surfaceElevated`
      // over the `background` scaffold; the three-step ramp is what carries
      // elevation in dark mode.
      for (final step in [
        AppColors.dark.surface,
        AppColors.dark.surfaceMuted,
        AppColors.dark.surfaceElevated,
      ]) {
        expect(step, isNot(AppColors.dark.background));
      }
      for (final ink in [
        AppColors.dark.textPrimary,
        AppColors.dark.textSecondary,
      ]) {
        expect(
          _contrast(ink, AppColors.dark.surfaceElevated),
          greaterThanOrEqualTo(_aa),
        );
      }
      expect(
        _contrast(AppColors.dark.textPrimary, AppColors.dark.surface),
        greaterThanOrEqualTo(_aa),
      );
    });
  });
}
