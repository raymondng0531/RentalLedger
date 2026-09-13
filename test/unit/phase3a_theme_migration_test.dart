import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_colors.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/utils/snackbar_utils.dart';
import 'package:rental_ledger/core/widgets/activity_card.dart';
import 'package:rental_ledger/core/widgets/animated_checkmark.dart';
import 'package:rental_ledger/core/widgets/balance_card.dart';
import 'package:rental_ledger/core/widgets/glass_card.dart';
import 'package:rental_ledger/core/widgets/loading_indicator.dart';
import 'package:rental_ledger/core/widgets/skeleton.dart';
import 'package:rental_ledger/core/widgets/status_badge.dart';
import 'package:rental_ledger/features/dashboard/presentation/widgets/activity_visuals.dart';
import 'package:rental_ledger/features/notifications/presentation/utils/notification_icon_utils.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// WCAG contrast ratio, as `(lighter + 0.05) / (darker + 0.05)`.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Pumps [child] under one of the app's real themes.
///
/// `darkTheme` is deliberately left unset so `theme` always wins: these tests
/// pin one mode at a time and must not depend on the host's platform
/// brightness. The trailing pump runs out `MaterialApp`'s theme cross-fade, so
/// a test that re-pumps in the other mode sees the new theme rather than the
/// old one still mid-animation. (`pumpAndSettle` is not an option here — the
/// progress indicators animate forever.)
///
/// The localization delegates mirror `app.dart`: several of the widgets pumped
/// through here (BalanceCard, AppLogo) resolve a localized string.
Future<void> _pumpThemed(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// The first `BoxDecoration.color` painted by a [Container] inside [scope].
///
/// Widgets like [GlassCard] stack more than one `Container` (a shadow cast and
/// the fill itself), so tests locate the fill by its colour rather than by
/// index.
Color? _fillColor(WidgetTester tester, Finder scope) {
  final containers = find.descendant(
    of: scope,
    matching: find.byType(Container),
  );
  for (final container in tester.widgetList<Container>(containers)) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }
  return null;
}

void main() {
  // ──────────────────────────────────────────────
  // Phase 3A tokens
  // ──────────────────────────────────────────────
  //
  // The three tokens this phase added. Each is pinned to the literal it had to
  // reproduce, because every one of them exists to keep a migrated call site
  // byte-identical in light mode.
  group('Phase 3A tokens', () {
    test('surfaceMuted is the V1.0 grey card fill', () {
      expect(AppColors.light.surfaceMuted.toARGB32(), 0xFFF5F5F5);
      // ActivityCard's shipped fill was `AppTheme.backgroundLight`.
      expect(AppColors.light.surfaceMuted, AppTheme.backgroundLight);
    });

    test('onAccent and onPrimary are both white in light mode', () {
      // This is what lets every migrated `Colors.white` foreground — the
      // snackbar ink, the close-FAB glyph, the balance card — stay identical.
      expect(AppColors.light.onAccent.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.light.onAccent, AppTheme.surfaceWhite);
      expect(AppColors.light.onPrimary, AppTheme.surfaceWhite);
    });

    test('placeholderTint is the old SkeletonCard grey', () {
      expect(AppColors.light.placeholderTint.toARGB32(), 0xFF9E9E9E);
      expect(
        AppColors.light.placeholderTint.toARGB32(),
        Colors.grey.toARGB32(),
      );
    });

    test('the dark variants differ from light and stay legible', () {
      expect(AppColors.dark.surfaceMuted, isNot(AppColors.light.surfaceMuted));
      expect(AppColors.dark.onAccent, isNot(AppColors.light.onAccent));
      expect(
        AppColors.dark.placeholderTint,
        isNot(AppColors.light.placeholderTint),
      );

      // surfaceMuted must sit *above* the page, not below it — a fill darker
      // than the background would vanish into it.
      expect(
        AppColors.dark.surfaceMuted.computeLuminance(),
        greaterThan(AppColors.dark.background.computeLuminance()),
      );

      // Dark accents are lightened, so the ink on them has to be dark.
      expect(
        _contrast(AppColors.dark.onAccent, AppColors.dark.success),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.dark.onAccent, AppColors.dark.warning),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.dark.onAccent, AppColors.dark.error),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('lerp still reproduces both palettes at its endpoints', () {
      expect(AppColors.light.lerp(AppColors.dark, 0.0), AppColors.light);
      expect(AppColors.light.lerp(AppColors.dark, 1.0), AppColors.dark);
    });
  });

  // ──────────────────────────────────────────────
  // The case the phase singled out: white on AppTheme.textSecondary
  // ──────────────────────────────────────────────
  group('close-FAB foreground (was AppTheme.textSecondary + Colors.white)', () {
    test('light mode is unchanged', () {
      // `AppTheme.textSecondary` with white ink, exactly as shipped.
      expect(
        _contrast(AppColors.light.onAccent, AppColors.light.textSecondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(AppColors.light.onAccent.toARGB32(), 0xFFFFFFFF);
    });

    test('dark mode flips the ink instead of leaving it white', () {
      // The dark textSecondary is light, so white ink would be about 2.1:1.
      expect(
        _contrast(Colors.white, AppColors.dark.textSecondary),
        lessThan(3),
      );
      expect(
        _contrast(AppColors.dark.onAccent, AppColors.dark.textSecondary),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  // ──────────────────────────────────────────────
  // GlassCard
  // ──────────────────────────────────────────────
  group('GlassCard', () {
    testWidgets('the default opacity reproduces the palette tint in light', (
      tester,
    ) async {
      await _pumpThemed(
        tester,
        const GlassCard(child: Text('glass')),
        brightness: Brightness.light,
      );

      // The A1 invariant for glass: `opacity: 0.75` was a raw 75%-white fill,
      // and it must still be exactly that.
      expect(
        _fillColor(tester, find.byType(GlassCard))?.toARGB32(),
        AppColors.light.glassFill.toARGB32(),
      );
      expect(
        _fillColor(tester, find.byType(GlassCard))?.toARGB32(),
        0xBFFFFFFF,
      );
    });

    testWidgets('the same default follows the theme into dark', (tester) async {
      await _pumpThemed(
        tester,
        const GlassCard(child: Text('glass')),
        brightness: Brightness.dark,
      );

      expect(
        _fillColor(tester, find.byType(GlassCard))?.toARGB32(),
        AppColors.dark.glassFill.toARGB32(),
      );
    });

    testWidgets('opacity still scales the fill', (tester) async {
      await _pumpThemed(
        tester,
        const GlassCard(opacity: 0.0, child: Text('glass')),
        brightness: Brightness.light,
      );

      expect(_fillColor(tester, find.byType(GlassCard))?.a, 0.0);
    });
  });

  // ──────────────────────────────────────────────
  // Skeleton primitives
  // ──────────────────────────────────────────────
  group('Skeleton', () {
    testWidgets('SkeletonBox defaults to the theme skeleton tint', (
      tester,
    ) async {
      await _pumpThemed(
        tester,
        const SkeletonBox(),
        brightness: Brightness.light,
      );
      expect(
        _fillColor(tester, find.byType(SkeletonBox)),
        AppColors.light.skeletonBase,
      );

      await _pumpThemed(
        tester,
        const SkeletonBox(),
        brightness: Brightness.dark,
      );
      expect(
        _fillColor(tester, find.byType(SkeletonBox)),
        AppColors.dark.skeletonBase,
      );
    });

    testWidgets('SkeletonBox still honours an explicit colour', (tester) async {
      await _pumpThemed(
        tester,
        const SkeletonBox(color: Colors.red),
        brightness: Brightness.dark,
      );

      expect(_fillColor(tester, find.byType(SkeletonBox)), Colors.red);
    });
  });

  // ──────────────────────────────────────────────
  // StatusBadge — legacy static API plus a themed render path
  // ──────────────────────────────────────────────
  group('StatusBadge', () {
    test('colorFor is unchanged and still reads the light palette', () {
      expect(StatusBadge.colorFor('pending'), AppTheme.statusPending);
      expect(StatusBadge.colorFor('approved'), AppTheme.statusApproved);
      expect(StatusBadge.colorFor('paid'), AppTheme.statusPaid);
      expect(StatusBadge.colorFor('rejected'), AppTheme.statusRejected);
      expect(
        StatusBadge.colorFor('Direct Payment'),
        AppTheme.statusDirectPayment,
      );
      expect(StatusBadge.colorFor('weird'), Colors.grey);
      expect(StatusBadge.colorFor('PENDING'), AppTheme.statusPending);
      expect(StatusBadge.colorFor('completed'), StatusBadge.colorFor('paid'));
    });

    test('resolve mirrors colorFor for the light palette', () {
      for (final status in [
        'pending',
        'approved',
        'paid',
        'completed',
        'rejected',
        'Direct Payment',
        'weird',
      ]) {
        expect(
          StatusBadge.resolve(status, AppColors.light),
          StatusBadge.colorFor(status),
          reason: status,
        );
      }
    });

    testWidgets('the widget renders the light status colour in light mode', (
      tester,
    ) async {
      await _pumpThemed(
        tester,
        const StatusBadge(status: 'approved'),
        brightness: Brightness.light,
      );

      expect(
        tester.widget<Text>(find.text('approved')).style?.color,
        AppTheme.statusApproved,
      );
    });

    testWidgets('the widget renders the lighter status colour in dark mode', (
      tester,
    ) async {
      await _pumpThemed(
        tester,
        const StatusBadge(status: 'approved'),
        brightness: Brightness.dark,
      );

      expect(
        tester.widget<Text>(find.text('approved')).style?.color,
        AppColors.dark.statusApproved,
      );
    });
  });

  // ──────────────────────────────────────────────
  // BalanceCard — foregrounds come off `onPrimary`
  // ──────────────────────────────────────────────
  group('BalanceCard', () {
    Widget build() => const SizedBox(
          width: 320,
          child: BalanceCard(balance: 0, isLoading: true),
        );

    testWidgets('light foregrounds are still plain white', (tester) async {
      await _pumpThemed(tester, build(), brightness: Brightness.light);

      expect(
        tester.widget<Text>(find.text('Central Account Balance')).style?.color,
        const Color(0xFFFFFFFF).withAlpha(200),
      );
      expect(
        _fillColor(tester, find.byType(BalanceCard))?.toARGB32(),
        const Color(0xFFFFFFFF).withAlpha(60).toARGB32(),
      );
    });

    testWidgets('dark mode inks the card content dark', (tester) async {
      await _pumpThemed(tester, build(), brightness: Brightness.dark);

      final label =
          tester.widget<Text>(find.text('Central Account Balance')).style?.color;
      expect(label, AppColors.dark.onPrimary.withAlpha(200));
      expect(
        _contrast(label!, AppColors.dark.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _fillColor(tester, find.byType(BalanceCard)),
        AppColors.dark.onPrimary.withAlpha(60),
      );
    });
  });

  // ──────────────────────────────────────────────
  // ActivityCard
  // ──────────────────────────────────────────────
  group('ActivityCard', () {
    Widget build() => const ActivityCard(
          title: 'Groceries',
          subtitle: 'Raymond • 6 Aug 2026',
          amount: 84.5,
          amountSign: '-',
          amountColor: AppTheme.errorRed,
          icon: Icons.shopping_cart_outlined,
          iconColor: AppTheme.errorRed,
        );

    testWidgets('light mode keeps the shipped grey fill and muted subtitle', (
      tester,
    ) async {
      await _pumpThemed(tester, build(), brightness: Brightness.light);

      expect(
        tester.widget<Card>(find.byType(Card)).color,
        AppTheme.backgroundLight,
      );
      expect(
        tester.widget<Text>(find.text('Raymond • 6 Aug 2026')).style?.color,
        AppTheme.textSecondary,
      );
    });

    testWidgets('dark mode lifts the fill above the page', (tester) async {
      await _pumpThemed(tester, build(), brightness: Brightness.dark);

      expect(
        tester.widget<Card>(find.byType(Card)).color,
        AppColors.dark.surfaceMuted,
      );
      expect(
        tester.widget<Text>(find.text('Raymond • 6 Aug 2026')).style?.color,
        AppColors.dark.textSecondary,
      );
      expect(
        _contrast(AppColors.dark.textSecondary, AppColors.dark.surfaceMuted),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  // ──────────────────────────────────────────────
  // Loading indicators
  // ──────────────────────────────────────────────
  group('Loading', () {
    testWidgets('LoadingIndicator follows the theme', (tester) async {
      await _pumpThemed(
        tester,
        const LoadingIndicator(message: 'Loading bills'),
        brightness: Brightness.light,
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        AppTheme.primaryGreen,
      );

      await _pumpThemed(
        tester,
        const LoadingIndicator(message: 'Loading bills'),
        brightness: Brightness.dark,
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        AppColors.dark.primary,
      );
      expect(
        tester.widget<Text>(find.text('Loading bills')).style?.color,
        AppColors.dark.textSecondary,
      );
    });

    testWidgets('SkeletonCard keeps its 30-alpha grey in light', (
      tester,
    ) async {
      await _pumpThemed(
        tester,
        const SkeletonCard(),
        brightness: Brightness.light,
      );

      expect(
        _fillColor(tester, find.byType(SkeletonCard))?.toARGB32(),
        Colors.grey.withAlpha(30).toARGB32(),
      );
    });
  });

  // ──────────────────────────────────────────────
  // Snackbars
  // ──────────────────────────────────────────────
  group('SnackbarUtils', () {
    /// Shows a snackbar from inside the pumped app so it has a messenger.
    Future<void> show(
      WidgetTester tester,
      Brightness brightness,
      void Function(BuildContext) show,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.lightTheme
              : AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      show(captured);
      await tester.pump();
    }

    testWidgets('success keeps the shipped green with white ink in light', (
      tester,
    ) async {
      await show(
        tester,
        Brightness.light,
        (context) => SnackbarUtils.showSuccess(context, 'Saved'),
      );

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, AppTheme.successGreen);
      expect(
        tester.widget<Text>(find.text('Saved')).style?.color?.toARGB32(),
        0xFFFFFFFF,
      );
    });

    testWidgets('dark mode lightens the fill and inks it dark', (
      tester,
    ) async {
      await show(
        tester,
        Brightness.dark,
        (context) => SnackbarUtils.showSuccess(context, 'Saved'),
      );

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, AppColors.dark.success);

      final ink = tester.widget<Text>(find.text('Saved')).style?.color;
      expect(ink, AppColors.dark.onAccent);
      expect(_contrast(ink!, AppColors.dark.success), greaterThanOrEqualTo(4.5));
    });

    testWidgets('each severity reads its own semantic token', (tester) async {
      final cases = <(void Function(BuildContext, String), Color)>[
        (SnackbarUtils.showError, AppTheme.errorRed),
        (SnackbarUtils.showWarning, AppTheme.warningOrange),
        (SnackbarUtils.showInfo, AppTheme.statusApproved),
      ];

      for (final (trigger, expected) in cases) {
        await show(
          tester,
          Brightness.light,
          (context) => trigger(context, 'x'),
        );
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
          expected,
        );
      }
    });
  });

  // ──────────────────────────────────────────────
  // AnimatedCheckmark
  // ──────────────────────────────────────────────
  group('AnimatedCheckmark', () {
    test('defaults to the theme rather than a baked-in colour', () {
      expect(const AnimatedCheckmark().color, isNull);
    });

    testWidgets('renders in both themes without an explicit colour', (
      tester,
    ) async {
      await _pumpThemed(
        tester,
        const AnimatedCheckmark(),
        brightness: Brightness.light,
      );
      expect(find.byType(CustomPaint), findsWidgets);

      await _pumpThemed(
        tester,
        const AnimatedCheckmark(),
        brightness: Brightness.dark,
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ──────────────────────────────────────────────
  // Class B helpers — palette passed in, not baked in
  // ──────────────────────────────────────────────
  group('activity_visuals', () {
    test('status colours come from the supplied palette', () {
      expect(
        activityStatusColor('paid', colors: AppColors.light),
        AppTheme.successGreen,
      );
      expect(
        activityStatusColor('paid', colors: AppColors.dark),
        AppColors.dark.success,
      );
      expect(
        activityStatusColor('rejected', colors: AppColors.dark),
        AppColors.dark.error,
      );
      expect(
        activityStatusColor('approved', colors: AppColors.dark),
        AppColors.dark.statusApproved,
      );
      expect(
        activityStatusColor(null, colors: AppColors.dark),
        AppColors.dark.statusPending,
      );
    });

    test('amount signs keep their light-mode colours', () {
      expect(
        activityAmount('deposit', colors: AppColors.light),
        ('+', AppTheme.successGreen),
      );
      expect(
        activityAmount('payment', colors: AppColors.light),
        ('-', AppTheme.errorRed),
      );
      expect(
        activityAmount('deposit', colors: AppColors.dark),
        ('+', AppColors.dark.success),
      );
    });

    test('icons take the palette tint', () {
      expect(
        activityVisual('deposit', null, null, false, colors: AppColors.dark),
        (Icons.savings_outlined, AppColors.dark.success),
      );
      expect(
        activityVisual('payment', null, null, false, colors: AppColors.dark),
        (Icons.credit_card_rounded, AppColors.dark.statusDirectPayment),
      );
      expect(
        activityVisual('payment', null, null, true, colors: AppColors.light),
        (Icons.receipt_long_rounded, AppTheme.successGreen),
      );
    });

    test('chips take the palette too', () async {
      // The chip helper is pure and still has no `BuildContext`, so the active
      // locale is passed in explicitly — the palette assertions below are
      // unaffected by which locale it is.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final chips = activityChips(
        'deposit',
        'Deposit',
        null,
        null,
        null,
        const {},
        colors: AppColors.dark,
        l10n: l10n,
      );

      expect(chips.map((c) => c.color), [
        AppColors.dark.success,
        AppColors.dark.statusApproved,
      ]);
    });
  });

  group('notificationIconFor', () {
    test('light mode is unchanged', () {
      expect(
        notificationIconFor('Expense Approved', colors: AppColors.light),
        (Icons.check_circle_outline, AppTheme.successGreen),
      );
      expect(
        notificationIconFor('Expense Rejected', colors: AppColors.light),
        (Icons.cancel_outlined, AppTheme.errorRed),
      );
      expect(
        notificationIconFor('anything else', colors: AppColors.light),
        (Icons.notifications_outlined, AppTheme.textSecondary),
      );
    });

    test('dark mode reads the dark palette', () {
      expect(
        notificationIconFor('Expense Approved', colors: AppColors.dark).$2,
        AppColors.dark.success,
      );
      expect(
        notificationIconFor('Expense Submitted', colors: AppColors.dark).$2,
        AppColors.dark.warning,
      );
      expect(
        notificationIconFor('Payment Completed', colors: AppColors.dark).$2,
        AppColors.dark.statusApproved,
      );
    });
  });

  // ──────────────────────────────────────────────
  // App shell tokens
  // ──────────────────────────────────────────────
  //
  // `_AppShell` builds the app router, which needs Firebase, so it cannot be
  // pumped here. These pin the token *choices* it makes instead.
  group('app shell tokens', () {
    test('the bottom bar keeps its opaque V1.0 white', () {
      // `surface`, not `glassBarFill` — the latter is translucent by design
      // (0xF7FFFFFF) and would have changed the shipped light bar.
      expect(AppColors.light.surface.toARGB32(), 0xFFFFFFFF);
      expect(
        AppColors.light.glassBarFill.toARGB32(),
        isNot(AppColors.light.surface.toARGB32()),
      );
    });

    test('the speed-dial chips keep their opaque white', () {
      expect(AppColors.light.surfaceElevated.toARGB32(), 0xFFFFFFFF);
    });

    test('dark shell surfaces differ from the page behind them', () {
      expect(AppColors.dark.surface, isNot(AppColors.dark.background));
      expect(AppColors.dark.surfaceElevated, isNot(AppColors.dark.surface));
      expect(
        _contrast(AppColors.dark.surface, AppColors.dark.background),
        greaterThan(1.0),
      );
    });
  });
}
