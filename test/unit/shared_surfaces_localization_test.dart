import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/widgets/app_logo.dart';
import 'package:rental_ledger/core/widgets/balance_card.dart';
import 'package:rental_ledger/core/widgets/error_display.dart';
import 'package:rental_ledger/core/widgets/receipt_viewer.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 3 — the shared surfaces: the app shell's navigation labels, the
/// router's 404 / missing-payload fallbacks, and the four shared core widgets.
///
/// Two layers are proved here, and they are different in kind:
///
/// 1. **The key contract.** Every Phase 3 key resolves to the expected string in
///    *both* locales. gen-l10n silently falls back to the template for a key
///    missing from `app_ms.arb`, so a forgotten translation would ship as
///    English — the table below pins the Malay value, and separately asserts
///    that a key meant to be translated does not resolve to its English twin.
/// 2. **Live rendering and switching.** The shared widgets are pumped through
///    the real locale wiring and re-pumped under the other locale, so "switching
///    locale updates the shared UI" is observed on screen rather than inferred
///    from the lookup.
///
/// The shell chrome itself (drawer / bottom bar / speed dial) is verified at
/// layer 1 only: it lives inside `app_router.dart`'s private `_AppShell`, which
/// is only reachable by booting the real router against Firebase. No test in
/// this suite pumps it, and inventing that harness is out of scope for a
/// string-migration phase.

/// One Phase 3 key: how to read it, and what each locale must resolve it to.
class _Key {
  const _Key(this.name, this.read, {required this.en, required this.ms});

  final String name;
  final String Function(AppLocalizations) read;

  /// The exact string required from `app_en.arb`. Where a string shipped before
  /// the migration, this is that string verbatim, so the table doubles as the
  /// wording-parity check.
  final String en;

  /// The exact string required from `app_ms.arb`.
  final String ms;
}

/// Deliberately identical in both locales.
///
/// * `languageEnglish` / `languageMalay` — a language is listed in its own
///   language, so someone who switched by accident can still find their way
///   back, and "Bahasa Melayu" is what Malay speakers call the language.
/// * `actionDeposit` — "deposit" is the ordinary word in Malaysian banking
///   Malay, not an untranslated English borrowing. Forcing a synonym would make
///   the label less clear, not more.
const _sameInBothLocales = <String>{
  'languageEnglish',
  'languageMalay',
  'actionDeposit',
  // Phases 5–15 additions — each one a deliberate decision, not an untranslated
  // key:
  'txnTypeDeposit', // "deposit" is the ordinary word in Malaysian banking Malay
  'categoryInternet', // no distinct Malay form in common use
  'labelStatus', // "status" is the ordinary Malay word, not a borrowing
  'actionEdit', // "edit" is the ordinary Malay word, not a borrowing
};

final _keys = <_Key>[
  // ── Settings language picker (Phase 2, pinned here so the shared-surface
  //    table is complete in one place) ──
  _Key('languageSectionTitle', (l) => l.languageSectionTitle,
      en: 'Language', ms: 'Bahasa'),
  _Key('languageEnglish', (l) => l.languageEnglish,
      en: 'English', ms: 'English'),
  _Key('languageMalay', (l) => l.languageMalay,
      en: 'Bahasa Melayu', ms: 'Bahasa Melayu'),

  // ── Bottom navigation ──
  _Key('navHome', (l) => l.navHome, en: 'Home', ms: 'Utama'),
  _Key('navHistory', (l) => l.navHistory, en: 'History', ms: 'Sejarah'),
  _Key('navExpenses', (l) => l.navExpenses, en: 'Expenses', ms: 'Perbelanjaan'),
  _Key('navReports', (l) => l.navReports, en: 'Reports', ms: 'Laporan'),

  // ── Drawer ──
  _Key('navDashboard', (l) => l.navDashboard,
      en: 'Dashboard', ms: 'Papan Pemuka'),
  _Key('navBillHistory', (l) => l.navBillHistory,
      en: 'Bill History', ms: 'Sejarah Bil'),
  _Key('navMembers', (l) => l.navMembers, en: 'Members', ms: 'Ahli'),
  _Key('navNotifications', (l) => l.navNotifications,
      en: 'Notifications', ms: 'Pemberitahuan'),
  _Key('navSettings', (l) => l.navSettings, en: 'Settings', ms: 'Tetapan'),
  _Key('actionSignOut', (l) => l.actionSignOut,
      en: 'Sign Out', ms: 'Log Keluar'),
  _Key('drawerMyHouses', (l) => l.drawerMyHouses,
      en: 'MY HOUSES', ms: 'RUMAH SAYA'),

  // ── Speed dial ──
  _Key('actionDirectPayment', (l) => l.actionDirectPayment,
      en: 'Direct Payment', ms: 'Bayaran Terus'),
  _Key('actionDeposit', (l) => l.actionDeposit, en: 'Deposit', ms: 'Deposit'),
  _Key('actionAddExpense', (l) => l.actionAddExpense,
      en: 'Add Expense', ms: 'Tambah Perbelanjaan'),

  // ── Router surfaces ──
  _Key('pageNotFoundTitle', (l) => l.pageNotFoundTitle,
      en: 'Page not found', ms: 'Halaman tidak dijumpai'),
  _Key('pageNotFoundMessage', (l) => l.pageNotFoundMessage,
      en: 'The page you are looking for does not exist.',
      ms: 'Halaman yang anda cari tidak wujud.'),
  _Key('actionGoHome', (l) => l.actionGoHome, en: 'Go Home', ms: 'Ke Utama'),
  _Key('unableToOpenItem', (l) => l.unableToOpenItem,
      en: 'Unable to open this item.', ms: 'Tidak dapat membuka item ini.'),

  // ── Shared widgets ──
  _Key('errorGenericMessage', (l) => l.errorGenericMessage,
      en: 'Something went wrong. Please try again.',
      ms: 'Sesuatu tidak kena. Sila cuba lagi.'),
  _Key('actionTryAgain', (l) => l.actionTryAgain,
      en: 'Try Again', ms: 'Cuba Lagi'),
  _Key('centralAccountBalance', (l) => l.centralAccountBalance,
      en: 'Central Account Balance', ms: 'Baki Akaun Pusat'),
  _Key('receiptTitle', (l) => l.receiptTitle, en: 'Receipt', ms: 'Resit'),
  _Key('appTagline', (l) => l.appTagline,
      en: 'Your household finances, simplified',
      ms: 'Kewangan rumah anda, dipermudah'),

  // ── Phases 5–15: the stored vocabulary, displayed localized ──
  // Every one of these has a *stored* counterpart that must stay English; the
  // table pins the display side, and phase5_vocabulary_test pins the storage
  // side.
  _Key('statusPending', (l) => l.statusPending, en: 'Pending', ms: 'Menunggu'),
  _Key('statusApproved', (l) => l.statusApproved,
      en: 'Approved', ms: 'Diluluskan'),
  _Key('statusRejected', (l) => l.statusRejected,
      en: 'Rejected', ms: 'Ditolak'),
  _Key('statusPaid', (l) => l.statusPaid, en: 'Paid', ms: 'Dibayar'),
  _Key('statusSubmitted', (l) => l.statusSubmitted,
      en: 'Submitted', ms: 'Dihantar'),
  _Key('txnTypeDeposit', (l) => l.txnTypeDeposit,
      en: 'Deposit', ms: 'Deposit'),
  _Key('txnTypeReimbursement', (l) => l.txnTypeReimbursement,
      en: 'Reimbursement', ms: 'Bayaran Balik'),
  _Key('txnTypeDirectPayment', (l) => l.txnTypeDirectPayment,
      en: 'Direct Payment', ms: 'Bayaran Terus'),
  _Key('txnTypeAdjustment', (l) => l.txnTypeAdjustment,
      en: 'Adjustment', ms: 'Pelarasan'),
  _Key('paymentSourcePersonal', (l) => l.paymentSourcePersonal,
      en: 'Personal', ms: 'Peribadi'),
  _Key('paymentSourceCentral', (l) => l.paymentSourceCentral,
      en: 'Central Account', ms: 'Akaun Pusat'),
  _Key('paymentMethodCash', (l) => l.paymentMethodCash,
      en: 'Cash', ms: 'Tunai'),
  _Key('paymentMethodBankTransfer', (l) => l.paymentMethodBankTransfer,
      en: 'Bank Transfer', ms: 'Pindahan Bank'),
  _Key('paymentMethodEWallet', (l) => l.paymentMethodEWallet,
      en: 'e-Wallet', ms: 'e-Dompet'),

  // ── Phases 5–15: default category display labels ──
  _Key('categoryRent', (l) => l.categoryRent, en: 'Rent', ms: 'Sewa'),
  _Key('categoryUtilities', (l) => l.categoryUtilities,
      en: 'Utilities', ms: 'Utiliti'),
  _Key('categoryFood', (l) => l.categoryFood, en: 'Food', ms: 'Makanan'),
  _Key('categoryHousehold', (l) => l.categoryHousehold,
      en: 'Household', ms: 'Rumahtangga'),
  _Key('categoryMaintenance', (l) => l.categoryMaintenance,
      en: 'Maintenance', ms: 'Penyelenggaraan'),
  _Key('categoryInternet', (l) => l.categoryInternet,
      en: 'Internet', ms: 'Internet'),
  _Key('categoryOther', (l) => l.categoryOther, en: 'Other', ms: 'Lain-lain'),

  // ── Phases 5–15: shared actions ──
  _Key('actionBack', (l) => l.actionBack, en: 'Back', ms: 'Kembali'),
  _Key('actionSave', (l) => l.actionSave, en: 'Save', ms: 'Simpan'),
  _Key('actionCancel', (l) => l.actionCancel, en: 'Cancel', ms: 'Batal'),
  _Key('actionDelete', (l) => l.actionDelete, en: 'Delete', ms: 'Padam'),
  _Key('actionEdit', (l) => l.actionEdit, en: 'Edit', ms: 'Edit'),
  _Key('actionClose', (l) => l.actionClose, en: 'Close', ms: 'Tutup'),

  // ── Phases 5–15: shared field labels ──
  _Key('labelStatus', (l) => l.labelStatus, en: 'Status', ms: 'Status'),
  _Key('labelCategory', (l) => l.labelCategory,
      en: 'Category', ms: 'Kategori'),
  _Key('labelDueDate', (l) => l.labelDueDate,
      en: 'Due Date', ms: 'Tarikh Akhir'),
  _Key('labelTreasurer', (l) => l.labelTreasurer,
      en: 'Treasurer', ms: 'Bendahari'),

  // ── Phase 15: failure presentation ──
  _Key('errorNetwork', (l) => l.errorNetwork,
      en: 'No internet connection.', ms: 'Tiada sambungan internet.'),
  _Key('errorPermission', (l) => l.errorPermission,
      en: 'You do not have permission to do that.',
      ms: 'Anda tiada kebenaran untuk melakukannya.'),
  _Key('errorNotFound', (l) => l.errorNotFound,
      en: 'We could not find that item.', ms: 'Kami tidak menjumpai item itu.'),
  _Key('errorAuthentication', (l) => l.errorAuthentication,
      en: 'Please sign in again.', ms: 'Sila log masuk semula.'),
];

late AppLocalizations _en;
late AppLocalizations _ms;

/// Pumps [child] under the app's real theme wiring and one locale.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Locale locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

/// The whole app's localization wiring in miniature: the locale is state, so
/// flipping it re-resolves every lookup in the tree — exactly what
/// `AppSettings.language` does to `MaterialApp.router`.
Widget _localeSwitchingApp(ValueNotifier<Locale> locale, Widget child) {
  return ValueListenableBuilder<Locale>(
    valueListenable: locale,
    builder: (context, value, _) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: value,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
    _ms = await AppLocalizations.delegate.load(const Locale('ms'));
  });

  group('key contract', () {
    for (final key in _keys) {
      test('${key.name} resolves in both locales', () {
        expect(key.read(_en), key.en, reason: 'app_en.arb ${key.name}');
        expect(key.read(_ms), key.ms, reason: 'app_ms.arb ${key.name}');
      });
    }

    test('every key resolves to a non-empty string', () {
      for (final key in _keys) {
        expect(key.read(_en), isNotEmpty, reason: '${key.name} (en)');
        expect(key.read(_ms), isNotEmpty, reason: '${key.name} (ms)');
      }
    });

    test('no key is missing a Malay translation', () {
      // gen-l10n falls back to the template for a key absent from app_ms.arb,
      // which would ship English in a Malay UI with no build error. Anything
      // that resolves identically in both locales must be a documented choice.
      final untranslated = <String>[
        for (final key in _keys)
          if (key.read(_ms) == key.read(_en) &&
              !_sameInBothLocales.contains(key.name))
            key.name,
      ];

      expect(
        untranslated,
        isEmpty,
        reason: 'these keys fall back to English in Malay — either translate '
            'them in lib/l10n/app_ms.arb or add them to _sameInBothLocales',
      );
    });

    test('the locale-identical keys are identical on purpose', () {
      for (final name in _sameInBothLocales) {
        final key = _keys.firstWhere((k) => k.name == name);
        expect(key.read(_ms), key.read(_en));
      }
    });

    test('the product name is never translated', () {
      // 'Rental Ledger' is a proper noun. It is not an ARB key at all — it
      // stays `AppConstants.appName` — so no locale can reach it.
      expect(_en.appTagline, isNot(contains('Rental Ledger')));
      expect(_ms.appTagline, isNot(contains('Rental Ledger')));
    });
  });

  group('ErrorDisplay', () {
    testWidgets('falls back to the localized message and retry label',
        (tester) async {
      await _pump(tester, ErrorDisplay(onRetry: () {}),
          locale: const Locale('en'));

      expect(find.text('Something went wrong. Please try again.'),
          findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('renders Malay under a Malay locale', (tester) async {
      await _pump(tester, ErrorDisplay(onRetry: () {}),
          locale: const Locale('ms'));

      expect(find.text('Sesuatu tidak kena. Sila cuba lagi.'), findsOneWidget);
      expect(find.text('Cuba Lagi'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('a caller message still wins over the fallback',
        (tester) async {
      await _pump(tester, const ErrorDisplay(message: 'Invoice 42 is missing.'),
          locale: const Locale('ms'));

      // Caller copy is the caller's to localize — the widget must not replace
      // it with its own fallback.
      expect(find.text('Invoice 42 is missing.'), findsOneWidget);
      expect(find.text('Sesuatu tidak kena. Sila cuba lagi.'), findsNothing);
    });

    testWidgets('hides the retry button without a callback', (tester) async {
      await _pump(tester, const ErrorDisplay(), locale: const Locale('en'));

      expect(find.text('Try Again'), findsNothing);
    });
  });

  group('BalanceCard', () {
    testWidgets('falls back to the localized label', (tester) async {
      await _pump(tester, const BalanceCard(balance: 1234.5),
          locale: const Locale('en'));
      expect(find.text('Central Account Balance'), findsOneWidget);

      await _pump(tester, const BalanceCard(balance: 1234.5),
          locale: const Locale('ms'));
      expect(find.text('Baki Akaun Pusat'), findsOneWidget);
      expect(find.text('Central Account Balance'), findsNothing);
    });

    testWidgets('a caller label still wins over the fallback', (tester) async {
      await _pump(
        tester,
        const BalanceCard(balance: 10, label: 'Petty Cash'),
        locale: const Locale('ms'),
      );

      expect(find.text('Petty Cash'), findsOneWidget);
      expect(find.text('Baki Akaun Pusat'), findsNothing);
    });
  });

  group('ReceiptViewer', () {
    testWidgets('falls back to the localized title', (tester) async {
      await _pump(tester, const ReceiptViewer(image: SizedBox.shrink()),
          locale: const Locale('en'));
      expect(find.text('Receipt'), findsOneWidget);

      await _pump(tester, const ReceiptViewer(image: SizedBox.shrink()),
          locale: const Locale('ms'));
      expect(find.text('Resit'), findsOneWidget);
      expect(find.text('Receipt'), findsNothing);
    });

    testWidgets('a caller title still wins over the fallback', (tester) async {
      await _pump(
        tester,
        const ReceiptViewer(
          image: SizedBox.shrink(),
          title: 'Receipt / Proof',
        ),
        locale: const Locale('ms'),
      );

      expect(find.text('Receipt / Proof'), findsOneWidget);
      expect(find.text('Resit'), findsNothing);
    });
  });

  group('AppLogo', () {
    testWidgets('localizes the tagline but never the app name', (tester) async {
      await _pump(tester, const AppLogo(), locale: const Locale('en'));
      expect(find.text('Rental Ledger'), findsOneWidget);
      expect(find.text('Your household finances, simplified'), findsOneWidget);

      await _pump(tester, const AppLogo(), locale: const Locale('ms'));
      expect(find.text('Rental Ledger'), findsOneWidget);
      expect(find.text('Kewangan rumah anda, dipermudah'), findsOneWidget);
    });

    testWidgets('drops the tagline entirely when disabled', (tester) async {
      await _pump(tester, const AppLogo(showTagline: false),
          locale: const Locale('ms'));

      expect(find.text('Kewangan rumah anda, dipermudah'), findsNothing);
      expect(find.text('Rental Ledger'), findsOneWidget);
    });
  });

  group('switching locale', () {
    testWidgets('re-resolves a shared widget in place', (tester) async {
      final locale = ValueNotifier<Locale>(const Locale('en'));
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        _localeSwitchingApp(locale, ErrorDisplay(onRetry: () {})),
      );
      expect(find.text('Try Again'), findsOneWidget);

      locale.value = const Locale('ms');
      await tester.pumpAndSettle();

      expect(find.text('Cuba Lagi'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);

      // ...and back again.
      locale.value = const Locale('en');
      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Cuba Lagi'), findsNothing);
    });

    testWidgets('re-resolves the shell-facing widgets in place', (tester) async {
      final locale = ValueNotifier<Locale>(const Locale('en'));
      addTearDown(locale.dispose);

      // AppLogo and BalanceCard, not ReceiptViewer: the viewer builds a
      // `Scaffold` of its own, so it cannot share a body with its siblings.
      // It is covered by the per-widget tests above.
      await tester.pumpWidget(
        _localeSwitchingApp(
          locale,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(),
              BalanceCard(balance: 5),
            ],
          ),
        ),
      );

      expect(find.text('Your household finances, simplified'), findsOneWidget);
      expect(find.text('Central Account Balance'), findsOneWidget);

      locale.value = const Locale('ms');
      await tester.pumpAndSettle();

      expect(find.text('Kewangan rumah anda, dipermudah'), findsOneWidget);
      expect(find.text('Baki Akaun Pusat'), findsOneWidget);
      expect(find.text('Central Account Balance'), findsNothing);
      expect(find.text('Your household finances, simplified'), findsNothing);
    });
  });
}
