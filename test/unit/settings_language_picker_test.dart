import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/services/preferences_service.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/features/settings/presentation/pages/settings_page.dart';
import 'package:rental_ledger/features/settings/presentation/providers/settings_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 2 — the Settings language picker, now driven by the generated
/// [AppLocalizations] instead of hardcoded literals.
///
/// Scope: the three keys this phase migrates (`languageSectionTitle`,
/// `languageEnglish`, `languageMalay`) plus the persistence and immediate-
/// reflection behaviour behind them. Every other Settings string is still
/// hardcoded on purpose, so the app is expected to stay part English until the
/// per-screen migration reaches those areas.

final _now = DateTime(2026, 8);

final _user = UserEntity(
  uid: 'user1',
  email: 'alice@example.com',
  displayName: 'Alice',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'h1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: 'user1',
  createdAt: _now,
);

final _members = <HouseMemberEntity>[
  HouseMemberEntity(
    memberId: 'm1',
    houseId: 'h1',
    userId: 'user1',
    role: 'Treasurer',
    joinedAt: _now,
    displayName: 'Alice',
    email: 'alice@example.com',
  ),
];

List<Override> _overrides(SharedPreferences prefs) => <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWith((ref) => _user),
      currentHouseProvider.overrideWith((ref) => _house),
      membersStreamProvider.overrideWith((ref) => Stream.value(_members)),
    ];

/// Pumps the real [SettingsPage] behind the real `app.dart` wiring: the locale
/// comes from `AppSettings.language` and the tree carries the generated
/// delegates. A fresh [ProviderScope] per call, so calling it twice over the
/// same store is exactly what a relaunch does.
Future<void> _pumpSettings(
  WidgetTester tester,
  SharedPreferences prefs,
) async {
  // Tall enough that every lazily-built section is actually mounted.
  await tester.binding.setSurfaceSize(const Size(800, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(prefs),
      child: Consumer(
        builder: (context, ref, _) {
          final language = ref.watch(
            appSettingsProvider.select((settings) => settings.language),
          );
          return MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          );
        },
      ),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask
  await tester.pumpAndSettle();
}

/// Lets the fire-and-forget persistence write in `setLanguage` settle.
///
/// A `pump`, not `Future.delayed`: `testWidgets` bodies run inside a fake-async
/// zone whose clock only advances when the tester pumps, so awaiting a real
/// timer here would hang the test rather than flush the write.
Future<void> _flushWrites(WidgetTester tester) => tester.pump();

/// The picker sheet's own copy of a label — the page behind it is still in the
/// tree while the sheet is open, so an unscoped `find.text` would match twice.
Finder _inSheet(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text),
    );

/// Opens the language picker from the Language tile.
Future<void> _openPicker(WidgetTester tester, String tileTitle) async {
  await tester.tap(find.text(tileTitle));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh in-memory store per test — no cross-test bleed.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('English (default)', () {
    testWidgets('the language tile reads Language / English', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await _pumpSettings(tester, prefs);

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Bahasa'), findsNothing);
    });

    testWidgets('the picker lists both languages, in their own language',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);

      await _openPicker(tester, 'Language');

      expect(_inSheet('Bahasa Melayu'), findsOneWidget);
      expect(_inSheet('English'), findsOneWidget);
      // The header is ambient-locale driven, so in English it reads "Language".
      expect(_inSheet('Language'), findsOneWidget);
    });

    testWidgets('the current choice carries the check mark', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);

      await _openPicker(tester, 'Language');

      final checked = tester.widget<ListTile>(
        find.ancestor(
          of: _inSheet('English'),
          matching: find.byType(ListTile),
        ),
      );
      final unchecked = tester.widget<ListTile>(
        find.ancestor(
          of: _inSheet('Bahasa Melayu'),
          matching: find.byType(ListTile),
        ),
      );

      expect(checked.trailing, isNotNull);
      expect(unchecked.trailing, isNull);
    });
  });

  group('Malay (persisted)', () {
    testWidgets('the language tile reads Bahasa / Bahasa Melayu',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ms',
      });
      final prefs = await SharedPreferences.getInstance();

      await _pumpSettings(tester, prefs);

      // `languageSectionTitle` follows the ambient locale...
      expect(find.text('Bahasa'), findsOneWidget);
      // ...while the tile's value names the selected language in its own
      // language, so it stays "Bahasa Melayu" — the value the user picked.
      expect(find.text('Bahasa Melayu'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
    });

    testWidgets('the picker header follows the ambient locale', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ms',
      });
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);

      await _openPicker(tester, 'Bahasa');

      expect(_inSheet('Bahasa'), findsOneWidget);
      expect(_inSheet('Bahasa Melayu'), findsOneWidget);
      expect(_inSheet('English'), findsOneWidget);
    });
  });

  group('switching', () {
    testWidgets('English → Bahasa Melayu takes effect immediately',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);
      expect(find.text('Language'), findsOneWidget);

      await _openPicker(tester, 'Language');
      await tester.tap(_inSheet('Bahasa Melayu'));
      await tester.pumpAndSettle();

      // The sheet closes, and the page behind it has already re-resolved.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Bahasa'), findsOneWidget);
      expect(find.text('Bahasa Melayu'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
    });

    testWidgets('Bahasa Melayu → English takes effect immediately',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ms',
      });
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);
      expect(find.text('Bahasa'), findsOneWidget);

      await _openPicker(tester, 'Bahasa');
      await tester.tap(_inSheet('English'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Bahasa'), findsNothing);
    });

    testWidgets('the check mark moves to the newly chosen language',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);

      await _openPicker(tester, 'Language');
      await tester.tap(_inSheet('Bahasa Melayu'));
      await tester.pumpAndSettle();

      await _openPicker(tester, 'Bahasa');

      expect(
        tester
            .widget<ListTile>(find.ancestor(
              of: _inSheet('Bahasa Melayu'),
              matching: find.byType(ListTile),
            ))
            .trailing,
        isNotNull,
      );
      expect(
        tester
            .widget<ListTile>(find.ancestor(
              of: _inSheet('English'),
              matching: find.byType(ListTile),
            ))
            .trailing,
        isNull,
      );
    });
  });

  group('persistence across a relaunch', () {
    testWidgets('a fresh install starts in English', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await _pumpSettings(tester, prefs);

      expect(find.text('Language'), findsOneWidget);
      expect(prefs.getString(PreferencesService.languageKey), isNull,
          reason: 'the default must not be written to the store — only an '
              'explicit choice should be');
    });

    testWidgets('Malay survives a relaunch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);

      await _openPicker(tester, 'Language');
      await tester.tap(_inSheet('Bahasa Melayu'));
      await tester.pumpAndSettle();
      await _flushWrites(tester);

      expect(prefs.getString(PreferencesService.languageKey), 'ms');

      // Relaunch: brand new ProviderScope over the same store.
      await _pumpSettings(tester, prefs);

      expect(find.text('Bahasa'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
    });

    testWidgets('switching back to English also survives a relaunch',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ms',
      });
      final prefs = await SharedPreferences.getInstance();
      await _pumpSettings(tester, prefs);

      await _openPicker(tester, 'Bahasa');
      await tester.tap(_inSheet('English'));
      await tester.pumpAndSettle();
      await _flushWrites(tester);

      expect(prefs.getString(PreferencesService.languageKey), 'en');

      await _pumpSettings(tester, prefs);

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Bahasa'), findsNothing);
    });
  });
}
