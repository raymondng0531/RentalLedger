import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_colors.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/services/preferences_service.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/pages/create_house_page.dart';
import 'package:rental_ledger/features/members/presentation/pages/join_house_page.dart';
import 'package:rental_ledger/features/members/presentation/pages/member_list_page.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/features/members/presentation/widgets/member_tile.dart';
import 'package:rental_ledger/features/notifications/domain/entities/notification_entity.dart';
import 'package:rental_ledger/features/notifications/presentation/pages/notification_page.dart';
import 'package:rental_ledger/features/notifications/presentation/providers/notification_provider.dart';
import 'package:rental_ledger/features/notifications/presentation/utils/notification_icon_utils.dart';
import 'package:rental_ledger/features/notifications/presentation/widgets/notification_toast.dart';
import 'package:rental_ledger/features/settings/presentation/pages/profile_page.dart';
import 'package:rental_ledger/features/settings/presentation/pages/settings_page.dart';
import 'package:rental_ledger/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 3E + 3F — Members, Notifications and Settings dark-mode migration.
///
/// Two different claims are checked here:
///
/// 1. **Light-mode parity.** Every colour these screens paint in light mode is
///    compared against the exact value V1.0 shipped — the legacy `AppTheme`
///    constant each call site used to read. A migration that silently
///    brightened or darkened the light UI fails here.
/// 2. **Dark-mode legibility.** The same elements are read back under
///    [AppTheme.darkTheme] and measured with WCAG contrast against the surface
///    they actually sit on. `computeLuminance()` ignores alpha, so anything
///    drawn at partial opacity is composited with [Color.alphaBlend] first.
///
/// Where V1.0 has a pre-existing contrast shortfall the test asserts the
/// **measured shortfall** rather than lowering the bar, and requires dark mode
/// to do no worse. Those numbers are pinned deliberately: "fixing" one by
/// editing a shared palette value becomes a visible, reviewable test failure
/// instead of a silent drift.

// ─────────────────────────────────────────────────────────────
// Measurement helpers
// ─────────────────────────────────────────────────────────────

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Composites a translucent fill onto its ground. Required before any contrast
/// claim about a `withAlpha` wash: `computeLuminance()` reads the fill's own
/// opaque channels and would otherwise report the *unmixed* colour.
Color _over(Color fill, Color ground) => Color.alphaBlend(fill, ground);

int _argb(Color c) => c.toARGB32();

const double _aa = 4.5;
const double _nonText = 3.0;

// ─────────────────────────────────────────────────────────────
// Pumping
// ─────────────────────────────────────────────────────────────

const _modes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];

AppColors _expected(ThemeMode mode) =>
    mode == ThemeMode.dark ? AppColors.dark : AppColors.light;

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page,
  List<Override> overrides, {
  ThemeMode mode = ThemeMode.light,
  bool followSettings = false,
}) async {
  // Tall enough that lazily-built ListViews build every section, so a colour
  // deep in a card is actually mounted and readable.
  await tester.binding.setSurfaceSize(const Size(800, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope per pump. Several tests sweep a list of pages in one
      // test body, and each page carries its own override list — Riverpod
      // asserts that an *existing* scope's override count never changes, so
      // reusing the element would fail on the second page. Re-keying forces a
      // new scope instead of an update.
      key: UniqueKey(),
      overrides: overrides,
      child: followSettings
          ? _SettingsDrivenApp(home: page)
          : MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: page,
            ),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask
  await tester.pumpAndSettle(); // entrance animations + the theme cross-fade
}

/// The `app.dart` wiring, in miniature: `themeMode` comes from
/// [appSettingsProvider] rather than a fixed value.
///
/// Only the Appearance-picker tests use this — a fixed `themeMode` is the
/// right harness for every other test, because it isolates "does this screen
/// paint the palette it was given" from "does choosing a mode reach the app".
/// But for the picker the second question IS the test, and a hardcoded
/// `themeMode` would make the page repaint-proof and the assertion vacuous.
class _SettingsDrivenApp extends ConsumerWidget {
  const _SettingsDrivenApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(appSettingsProvider.select((settings) => settings.themeMode));
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: home,
    );
  }
}

/// The palette actually registered on the rendered theme — proof the mode
/// really switched, rather than an assertion comparing light to light.
///
/// `AppColors` implements value equality, so this compares token by token.
AppColors _palette(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold).first);
  return Theme.of(ctx).extension<AppColors>() ?? AppColors.light;
}

// ─────────────────────────────────────────────────────────────
// Finders and style readers
// ─────────────────────────────────────────────────────────────

Finder _memberTile(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(MemberTile),
    );

CircleAvatar _memberAvatar(WidgetTester tester, String name) =>
    tester.widget<CircleAvatar>(
      find
          .descendant(
              of: _memberTile(name), matching: find.byType(CircleAvatar))
          .first,
    );

/// The nearest [Container] above [of]. Covers both spellings — a `Container`
/// with `color:` and one with a `BoxDecoration`.
Container _containerAbove(WidgetTester tester, Finder of) =>
    tester.widget<Container>(
      find.ancestor(of: of, matching: find.byType(Container)).first,
    );

/// The resolved fill of the nearest [Container] above [of].
Color _fillAbove(WidgetTester tester, Finder of) {
  final container = _containerAbove(tester, of);
  final decoration = container.decoration;
  if (decoration is BoxDecoration) return decoration.color!;
  return container.color!;
}

Finder _notifRow(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Material)).first;

Material _notifMaterial(WidgetTester tester, String title) =>
    tester.widget<Material>(_notifRow(title));

/// The unread dot is the only circle-decorated [Container] inside a row.
Container _dotIn(WidgetTester tester, String title) {
  final dot = find.descendant(
    of: _notifRow(title),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
    ),
  );
  expect(dot, findsOneWidget, reason: 'expected exactly one unread dot');
  return tester.widget<Container>(dot);
}

Color? _styleBg(ButtonStyle? style) =>
    style?.backgroundColor?.resolve(<WidgetState>{});

Color? _styleFg(ButtonStyle? style) =>
    style?.foregroundColor?.resolve(<WidgetState>{});

// ─────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────

final _now = DateTime(2026, 8);

final _treasurerUser = UserEntity(
  uid: 'user2',
  email: 'bob@example.com',
  displayName: 'Bob',
  createdAt: _now,
);

final _memberUser = UserEntity(
  uid: 'user1',
  email: 'alice@example.com',
  displayName: 'Alice',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'h1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: 'user2',
  createdAt: _now,
);

final _treasurer = HouseMemberEntity(
  memberId: 'm2',
  houseId: 'h1',
  userId: 'user2',
  role: 'Treasurer',
  joinedAt: _now,
  displayName: 'Bob',
  email: 'bob@example.com',
);

final _member = HouseMemberEntity(
  memberId: 'm1',
  houseId: 'h1',
  userId: 'user1',
  joinedAt: _now,
  displayName: 'Alice',
  email: 'alice@example.com',
);

final _members = <HouseMemberEntity>[_treasurer, _member];

List<Override> _memberOverrides({required bool viewerIsTreasurer}) => [
      currentUserProvider.overrideWith(
        (ref) => viewerIsTreasurer ? _treasurerUser : _memberUser,
      ),
      currentHouseProvider.overrideWith((ref) => _house),
      membersStreamProvider.overrideWith((ref) => Stream.value(_members)),
    ];

/// Settings and Profile read the signed-in user directly; `profileProvider`
/// derives from it, so one override feeds both the header and the form.
final _settingsOverrides = <Override>[
  currentUserProvider.overrideWith((ref) => _treasurerUser),
  currentHouseProvider.overrideWith((ref) => _house),
  membersStreamProvider.overrideWith((ref) => Stream.value(_members)),
];

/// One unread notification from today and one read one from weeks ago, so both
/// a Today and an Earlier group render. Grouping keys off `DateTime.now()`, so
/// the offsets are relative rather than fixed dates.
final _notifications = <NotificationEntity>[
  NotificationEntity(
    notificationId: 'n1',
    userId: 'user2',
    title: 'Expense Approved',
    body: 'Your claim of RM42.50 was approved by the Treasurer.',
    type: 'Expense Approved',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  NotificationEntity(
    notificationId: 'n2',
    userId: 'user2',
    title: 'Payment Completed',
    body: 'RM150.00 was paid from the Central Account.',
    type: 'Payment Completed',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
  ),
];

final _notificationOverrides = <Override>[
  notificationsStreamProvider
      .overrideWith((ref) => Stream.value(_notifications)),
];

// ─────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh in-memory store per test — no cross-test bleed.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ═══════════════════════════════════════════════════════════
  // Light-mode parity ledger
  // ═══════════════════════════════════════════════════════════

  group('light-mode parity — every mapped token IS the V1.0 value', () {
    test('members: primary / error / supporting text / dividers', () {
      const light = AppColors.light;

      expect(_argb(light.primary), _argb(AppTheme.primaryGreen));
      expect(_argb(light.error), _argb(AppTheme.errorRed));
      expect(_argb(light.textSecondary), _argb(AppTheme.textSecondary));
      expect(_argb(light.textHint), _argb(AppTheme.textHint));
      expect(_argb(light.divider), _argb(AppTheme.dividerColor));
    });

    test('the non-Treasurer avatar keeps the exact V1.0 swatch', () {
      // V1.0 painted `Colors.grey.withAlpha(30)` on a non-Treasurer's avatar.
      // Those two are not merely value-equal — they are the same object — and
      // the palette keeps the material swatch rather than a value-equal
      // literal so `withAlpha` and `==` behave identically. `same()` is the
      // strongest available statement of that; the light value is pinned
      // separately by `app_colors_test.dart`.
      expect(AppColors.light.statusNeutral, same(Colors.grey));
      expect(_argb(AppColors.light.statusNeutral), 0xFF9E9E9E);
    });

    test('settings: surface is the shipped white, not the page tone', () {
      const light = AppColors.light;

      // The Settings profile header hardcoded `Colors.white`; mapping it to
      // `background` would have shipped #F5F5F5 and silently changed light
      // mode. Same reasoning for the Create/Join House scaffolds.
      expect(_argb(light.surface), 0xFFFFFFFF);
      expect(_argb(light.surface), _argb(AppTheme.surfaceWhite));
      expect(
        _argb(light.surface),
        isNot(_argb(light.background)),
        reason: 'if these ever collapse, the mapping must be revisited',
      );
      expect(_argb(light.surfaceMuted), _argb(AppTheme.backgroundLight));
    });

    test('the accent inks are white in light mode', () {
      expect(_argb(AppColors.light.onAccent), 0xFFFFFFFF);
      expect(_argb(AppColors.light.onPrimary), 0xFFFFFFFF);
    });

    test('the toast fill is white in light mode, like every other card', () {
      // `surfaceElevated` diverges from the Phase 3A `SnackbarUtils` toast,
      // which uses `surface`. Both are #FFFFFF in light mode, so this choice
      // is invisible to the frozen light theme — the divergence exists only in
      // dark mode, and is justified by the separation measured below.
      expect(_argb(AppColors.light.surfaceElevated), 0xFFFFFFFF);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Members
  // ═══════════════════════════════════════════════════════════

  group('Members — avatars, roles, Treasurer indicators', () {
    for (final mode in _modes) {
      final colors = _expected(mode);

      testWidgets('${mode.name}: the Treasurer avatar and role badge',
          (tester) async {
        await _pumpPage(
          tester,
          const MemberListPage(),
          _memberOverrides(viewerIsTreasurer: false),
          mode: mode,
        );
        expect(_palette(tester), colors,
            reason: 'the page must actually render the ${mode.name} palette');

        expect(
          _memberAvatar(tester, 'Bob').backgroundColor,
          colors.primary.withAlpha(30),
        );
        expect(
          _fillAbove(
            tester,
            find.descendant(
              of: _memberTile('Bob'),
              matching: find.text('Treasurer'),
            ),
          ),
          colors.primary.withAlpha(20),
          reason: 'the role badge fill',
        );
        expect(
          tester
              .widget<Text>(find.descendant(
                of: _memberTile('Bob'),
                matching: find.text('Treasurer'),
              ))
              .style
              ?.color,
          colors.primary,
          reason: 'the role badge ink',
        );
      });

      testWidgets('${mode.name}: a non-Treasurer avatar is the palette neutral',
          (tester) async {
        await _pumpPage(
          tester,
          const MemberListPage(),
          _memberOverrides(viewerIsTreasurer: false),
          mode: mode,
        );

        expect(
          _memberAvatar(tester, 'Alice').backgroundColor,
          colors.statusNeutral.withAlpha(30),
        );
        // The initial is inked with the same neutral, not left to inherit —
        // an unset colour would take `textPrimary` and read as a heading.
        expect(
          tester
              .widget<Text>(find.descendant(
                of: _memberTile('Alice'),
                matching: find.text('A'),
              ))
              .style
              ?.color,
          colors.statusNeutral,
        );
      });

      testWidgets('${mode.name}: supporting text and the invite block',
          (tester) async {
        await _pumpPage(
          tester,
          const MemberListPage(),
          _memberOverrides(viewerIsTreasurer: false),
          mode: mode,
        );

        expect(
          tester.widget<Text>(find.text('bob@example.com')).style?.color,
          colors.textSecondary,
        );
        expect(
          tester
              .widget<Text>(find.descendant(
                of: _memberTile('Bob'),
                matching: find.textContaining('Joined'),
              ))
              .style
              ?.color,
          colors.textSecondary,
        );
        expect(
          tester
              .widget<Text>(
                  find.text('Share this code with housemates to join.'))
              .style
              ?.color,
          colors.textSecondary,
        );
        expect(
          tester.widget<Text>(find.text('Members')).style?.color,
          colors.textSecondary,
          reason: 'section headers are supporting ink',
        );
        expect(
          tester.widget<Text>(find.text('AB12CD')).style?.color,
          colors.primary,
        );
        expect(
          _fillAbove(tester, find.text('AB12CD')),
          colors.surfaceMuted,
          reason: 'the quiet block the invite code sits in',
        );
      });

      testWidgets('${mode.name}: Treasurer-only action inks', (tester) async {
        await _pumpPage(
          tester,
          const MemberListPage(),
          _memberOverrides(viewerIsTreasurer: true),
          mode: mode,
        );

        expect(
          tester
              .widget<Icon>(find.descendant(
                of: _memberTile('Alice'),
                matching: find.byIcon(Icons.admin_panel_settings_outlined),
              ))
              .color,
          colors.primary,
        );
        expect(
          tester
              .widget<Icon>(find.descendant(
                of: _memberTile('Alice'),
                matching: find.byIcon(Icons.remove_circle_outline),
              ))
              .color,
          colors.error,
        );
        // The Treasurer's own row never offers a remove action.
        expect(
          find.descendant(
            of: _memberTile('Bob'),
            matching: find.byIcon(Icons.remove_circle_outline),
          ),
          findsNothing,
        );
      });

      testWidgets('${mode.name}: the member "Leave house" outline',
          (tester) async {
        await _pumpPage(
          tester,
          const MemberListPage(),
          _memberOverrides(viewerIsTreasurer: false),
          mode: mode,
        );

        // A predicate rather than `byType`: `OutlinedButton.icon` builds a
        // private `_OutlinedButtonWithIcon` subclass, and `byType` matches the
        // exact runtime type.
        final leave = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Leave house'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          ),
        );
        expect(_styleFg(leave.style), colors.error);
        expect(
          leave.style?.side?.resolve(<WidgetState>{})?.color,
          colors.error,
        );
      });

      testWidgets('${mode.name}: the remove-confirm dialog stays readable',
          (tester) async {
        await _pumpPage(
          tester,
          const MemberListPage(),
          _memberOverrides(viewerIsTreasurer: true),
          mode: mode,
        );

        await tester.tap(find.descendant(
          of: _memberTile('Alice'),
          matching: find.byIcon(Icons.remove_circle_outline),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        final confirm = tester.widget<FilledButton>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        expect(_styleBg(confirm.style), colors.error);
        expect(_styleFg(confirm.style), colors.onAccent);
      });

      testWidgets('${mode.name}: Create / Join House sit on a themed sheet',
          (tester) async {
        for (final page in <Widget>[
          const CreateHousePage(),
          const JoinHousePage(),
        ]) {
          await _pumpPage(tester, page, const [], mode: mode);

          final scaffold =
              tester.widget<Scaffold>(find.byType(Scaffold).first);
          final appBar = tester.widget<AppBar>(find.byType(AppBar));

          expect(scaffold.backgroundColor, colors.surface,
              reason: 'a hardcoded white page would stay white in dark mode');
          expect(appBar.backgroundColor, colors.surface);
          // Not the V1.0 grey page tone — light mode must stay #FFFFFF.
          expect(scaffold.backgroundColor, isNot(colors.background));
        }
      });
    }

    test('the non-Treasurer avatar ink clears AA in dark, and improves', () {
      const light = AppColors.light;
      const dark = AppColors.dark;

      // Composited onto the card surface the avatar actually sits on.
      final lWash = _over(light.statusNeutral.withAlpha(30), light.surface);
      final dWash = _over(dark.statusNeutral.withAlpha(30), dark.surface);

      final lInk = _contrast(light.statusNeutral, lWash);
      final dInk = _contrast(dark.statusNeutral, dWash);

      // V1.0 ships grey-on-grey at 2.43:1 — a genuine light-mode shortfall,
      // frozen by the "light mode is frozen" rule and *recorded* here rather
      // than quietly repaired.
      expect(lInk, closeTo(2.43, 0.02));
      expect(lInk, lessThan(_aa));
      expect(dInk, greaterThan(_aa), reason: 'dark mode must clear AA');
      expect(dInk, greaterThan(lInk));
    });

    test('the Treasurer badge ink improves in dark mode', () {
      final lBadge = _over(
          AppColors.light.primary.withAlpha(20), AppColors.light.surface);
      final dBadge =
          _over(AppColors.dark.primary.withAlpha(20), AppColors.dark.surface);

      expect(_contrast(AppColors.light.primary, lBadge), closeTo(3.91, 0.02));
      expect(_contrast(AppColors.dark.primary, dBadge), greaterThan(_aa));
    });

    test('the invite code clears the large-text bar in both modes', () {
      // 24px bold — WCAG "large text", so the bar is 3:1, not 4.5:1.
      expect(
        _contrast(AppColors.light.primary, AppColors.light.surfaceMuted),
        greaterThan(_nonText),
      );
      expect(
        _contrast(AppColors.dark.primary, AppColors.dark.surfaceMuted),
        greaterThan(_aa),
      );
    });

    test('the destructive confirm button is legible in both modes', () {
      expect(
        _contrast(AppColors.light.onAccent, AppColors.light.error),
        closeTo(4.53, 0.02),
      );
      expect(
        _contrast(AppColors.dark.onAccent, AppColors.dark.error),
        greaterThan(_aa),
      );
    });

    test('section-header ink improves in dark mode', () {
      expect(
        _contrast(AppColors.light.textSecondary, AppColors.light.background),
        closeTo(4.43, 0.02),
      );
      expect(
        _contrast(AppColors.dark.textSecondary, AppColors.dark.background),
        greaterThan(_aa),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Notifications
  // ═══════════════════════════════════════════════════════════

  group('Notifications — rows, unread state, icons', () {
    for (final mode in _modes) {
      final colors = _expected(mode);

      testWidgets('${mode.name}: unread vs read row treatment',
          (tester) async {
        await _pumpPage(
          tester,
          const NotificationPage(),
          _notificationOverrides,
          mode: mode,
        );
        expect(_palette(tester), colors);

        expect(
          _notifMaterial(tester, 'Expense Approved').color,
          colors.primary.withAlpha(8),
          reason: 'the unread wash',
        );
        expect(
          _notifMaterial(tester, 'Payment Completed').color,
          Colors.transparent,
          reason: 'a read row paints no fill — the sentinel, not a colour',
        );
        expect(
          (_dotIn(tester, 'Expense Approved').decoration! as BoxDecoration)
              .color,
          colors.primary,
        );
        // A read row carries no dot at all.
        expect(
          find.descendant(
            of: _notifRow('Payment Completed'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
            ),
          ),
          findsNothing,
        );
      });

      testWidgets('${mode.name}: icon tile, body copy and timestamps',
          (tester) async {
        await _pumpPage(
          tester,
          const NotificationPage(),
          _notificationOverrides,
          mode: mode,
        );

        final (icon, iconColor) =
            notificationIconFor('Expense Approved', colors: colors);

        expect(
          tester
              .widget<Icon>(find.descendant(
                of: _notifRow('Expense Approved'),
                matching: find.byIcon(icon),
              ))
              .color,
          iconColor,
        );
        expect(
          _fillAbove(
            tester,
            find.descendant(
              of: _notifRow('Expense Approved'),
              matching: find.byIcon(icon),
            ),
          ),
          iconColor.withAlpha(25),
          reason: 'the tinted icon square',
        );

        expect(
          tester
              .widget<Text>(find.text(
                  'Your claim of RM42.50 was approved by the Treasurer.'))
              .style
              ?.color,
          colors.textSecondary,
        );
        expect(
          tester
              .widget<Text>(find.descendant(
                of: _notifRow('Expense Approved'),
                matching: find.textContaining(' · '),
              ))
              .style
              ?.color,
          colors.textHint,
          reason: 'the timestamp line is de-emphasised, not body copy',
        );
        expect(
          tester.widget<Text>(find.textContaining('Today,')).style?.color,
          colors.textSecondary,
        );
      });

      testWidgets('${mode.name}: the empty state still renders',
          (tester) async {
        await _pumpPage(
          tester,
          const NotificationPage(),
          [
            notificationsStreamProvider
                .overrideWith((ref) => Stream.value(const [])),
          ],
          mode: mode,
        );

        expect(find.text('No notifications yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${mode.name}: the toast paints a themed card',
          (tester) async {
        final controller = StreamController<List<NotificationEntity>>();
        addTearDown(controller.close);

        final baseline = NotificationEntity(
          notificationId: 'n0',
          userId: 'user2',
          title: 'Baseline',
          body: 'Establishes the toast watermark.',
          type: 'Deposit Recorded',
          isRead: true,
          createdAt: DateTime.now(),
        );

        await tester.binding.setSurfaceSize(const Size(600, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsStreamProvider
                  .overrideWith((ref) => controller.stream),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: const NotificationToastListener(
                child: Scaffold(body: SizedBox.expand()),
              ),
            ),
          ),
        );
        await tester.pump();

        // The first emission only sets the watermark — pre-existing
        // notifications must not all pop on launch.
        controller.add([baseline]);
        await tester.pump();
        await tester.pump();
        expect(find.byType(SnackBar), findsNothing);

        // A strictly newer notification pops the toast.
        controller.add([
          NotificationEntity(
            notificationId: 'n1',
            userId: 'user2',
            title: 'Expense Approved',
            body: 'Your claim was approved.',
            type: 'Expense Approved',
            createdAt: baseline.createdAt.add(const Duration(minutes: 1)),
          ),
          baseline,
        ]);
        await tester.pump(); // the stream delivers
        await tester.pump(); // the post-frame callback shows the snack bar
        await tester.pump(); // the snack bar builds

        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(
          snack.backgroundColor,
          colors.surfaceElevated,
          reason: 'a literal white toast would stay white in dark mode',
        );
        expect(
          (snack.shape! as RoundedRectangleBorder).side.color,
          colors.divider,
        );

        // Let the 3s auto-dismiss timer run out so the test ends clean.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      });
    }

    test('the unread wash is an alpha recipe, so dark is not a regression', () {
      const light = AppColors.light;
      const dark = AppColors.dark;

      final lRow = _over(light.primary.withAlpha(8), light.background);
      final dRow = _over(dark.primary.withAlpha(8), dark.background);

      // One fixed alpha composited on each ground yields the *same* separation
      // in both modes — so dark mode needs no different recipe, and raising it
      // would have changed the frozen light appearance.
      expect(_contrast(lRow, light.background), closeTo(1.039, 0.002));
      expect(_contrast(dRow, dark.background), closeTo(1.040, 0.002));
      expect(
        _contrast(dRow, dark.background),
        greaterThanOrEqualTo(_contrast(lRow, light.background) - 0.002),
      );
    });

    test('the unread dot is the load-bearing signal and strengthens in dark',
        () {
      // The wash is a whisper by V1.0 design, so the dot carries the state.
      // 3:1 is the graphical-object bar; both clear it and dark nearly doubles.
      expect(
        _contrast(AppColors.light.primary, AppColors.light.background),
        greaterThan(_nonText),
      );
      expect(
        _contrast(AppColors.dark.primary, AppColors.dark.background),
        greaterThan(
          _contrast(AppColors.light.primary, AppColors.light.background),
        ),
      );
    });

    test('the toast separates from the scaffold it floats above', () {
      // Light mode is byte-identical either way (`surface` and
      // `surfaceElevated` are both #FFFFFF); dark mode is the whole reason the
      // token is `surfaceElevated` — a shadow does less work on a dark ground.
      expect(
        _contrast(AppColors.light.surfaceElevated, AppColors.light.background),
        closeTo(1.090, 0.002),
      );
      expect(
        _contrast(AppColors.dark.surfaceElevated, AppColors.dark.background),
        greaterThan(
          _contrast(AppColors.dark.surface, AppColors.dark.background),
        ),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Settings
  // ═══════════════════════════════════════════════════════════

  group('Settings — page chrome, tiles, logout', () {
    for (final mode in _modes) {
      final colors = _expected(mode);

      testWidgets('${mode.name}: profile header, sections and Sign Out',
          (tester) async {
        await _pumpPage(
          tester,
          const SettingsPage(),
          _settingsOverrides,
          mode: mode,
        );
        expect(_palette(tester), colors);

        // The header Container's own fill — white in V1.0, and the single most
        // visible "this page stayed light" failure in dark mode.
        expect(
          _fillAbove(tester, find.text('Bob')),
          colors.surface,
        );
        expect(
          tester
              .widget<CircleAvatar>(find.byType(CircleAvatar).first)
              .backgroundColor,
          colors.primary.withAlpha(30),
        );
        expect(
          tester.widget<Text>(find.text('bob@example.com')).style?.color,
          colors.textSecondary,
        );
        expect(
          tester.widget<Text>(find.text('Appearance')).style?.color,
          colors.textSecondary,
          reason: 'section headers are supporting ink',
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.logout_rounded)).color,
          colors.error,
        );
        expect(
          tester
              .widget<ListTile>(find.ancestor(
                of: find.text('Sign Out'),
                matching: find.byType(ListTile),
              ))
              .titleTextStyle
              ?.color,
          colors.error,
        );
      });

      testWidgets('${mode.name}: picker sheets paint a themed surface',
          (tester) async {
        await _pumpPage(
          tester,
          const SettingsPage(),
          _settingsOverrides,
          mode: mode,
        );

        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.check)).color,
          colors.primary,
        );

        // SpringSheet paints no background of its own, so the sheet's entire
        // surface comes from the theme — a light sheet in dark mode would be
        // the visible bug this pins.
        expect(
          Theme.of(tester.element(find.byType(BottomSheet)))
              .bottomSheetTheme
              .backgroundColor,
          mode == ThemeMode.dark ? colors.surfaceElevated : null,
        );
      });

      testWidgets('${mode.name}: the Help dialog renders themed',
          (tester) async {
        await _pumpPage(
          tester,
          const SettingsPage(),
          _settingsOverrides,
          mode: mode,
        );

        await tester.tap(find.text('Help Center'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester
              .widget<Icon>(find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byIcon(Icons.receipt_long_outlined),
              ))
              .color,
          colors.primary,
        );
        expect(
          tester
              .widget<Text>(find.text(
                  'Tap + to add a new expense claim with receipt.'))
              .style
              ?.color,
          colors.textSecondary,
        );
      });

      testWidgets('${mode.name}: the Profile page avatar and logout row',
          (tester) async {
        await _pumpPage(
          tester,
          const ProfilePage(),
          _settingsOverrides,
          mode: mode,
        );

        expect(
          tester
              .widget<CircleAvatar>(find.byType(CircleAvatar).first)
              .backgroundColor,
          colors.primary.withAlpha(25),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.logout_rounded)).color,
          colors.error,
        );
        expect(
          tester
              .widget<ListTile>(find.ancestor(
                of: find.text('Sign Out'),
                matching: find.byType(ListTile),
              ))
              .titleTextStyle
              ?.color,
          colors.error,
        );
      });
    }

    testWidgets('the Profile page renders under a dark theme', (tester) async {
      await _pumpPage(
        tester,
        const ProfilePage(),
        _settingsOverrides,
        mode: ThemeMode.dark,
      );
      expect(_palette(tester), AppColors.dark);
      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // The Appearance selector
  // ═══════════════════════════════════════════════════════════

  group('Settings — Appearance reflects the persisted ThemeMode', () {
    test('the label mapping covers all three modes', () {
      expect(themeModeLabel(ThemeMode.system), 'System default');
      expect(themeModeLabel(ThemeMode.light), 'Light');
      expect(themeModeLabel(ThemeMode.dark), 'Dark');
      expect(ThemeMode.values.length, 3,
          reason: 'a new ThemeMode must not silently fall through');
    });

    for (final stored in ThemeMode.values) {
      testWidgets('the row reports the stored mode: ${stored.name}',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          PreferencesService.themeModeKey: stored.name,
        });
        final prefs = await SharedPreferences.getInstance();

        await _pumpPage(
          tester,
          const SettingsPage(),
          [
            ..._settingsOverrides,
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          // The render mode is independent of the stored row, so a stored
          // `dark` is read back while the page renders light (the harness
          // default) — that is what proves the subtitle reads the
          // *preference*, not the ambient theme.
        );

        expect(find.text('Theme'), findsOneWidget);
        expect(find.text(themeModeLabel(stored)), findsOneWidget);
        // The V1.0 placeholder must be gone.
        expect(find.text('Dark Mode'), findsNothing);
        expect(find.text('Coming soon'), findsNothing);
      });
    }

    testWidgets('the picker offers exactly System / Light / Dark',
        (tester) async {
      await _pumpPage(
        tester,
        const SettingsPage(),
        _settingsOverrides,
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      for (final mode in ThemeMode.values) {
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(themeModeLabel(mode)),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Follow your device or browser'), findsOneWidget);
    });

    testWidgets('the picker ticks the currently persisted mode',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.themeModeKey: ThemeMode.dark.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await _pumpPage(
        tester,
        const SettingsPage(),
        [
          ..._settingsOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();

      // Exactly one tick, and it sits on the stored row.
      final ticks = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.check),
      );
      expect(ticks, findsOneWidget);

      final tickedRow = tester.widget<ListTile>(
        find.ancestor(of: ticks, matching: find.byType(ListTile)),
      );
      expect((tickedRow.title! as Text).data, 'Dark');
    });

    testWidgets('choosing Dark repaints the page and persists',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await _pumpPage(
        tester,
        const SettingsPage(),
        [
          ..._settingsOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        mode: ThemeMode.system,
        followSettings: true,
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Dark'),
      ));
      await tester.pumpAndSettle();

      // The page followed the choice: the test platform brightness is light,
      // so an explicit Dark is the only thing that makes this render dark.
      expect(_palette(tester), AppColors.dark);
      // The row now reports it.
      expect(find.text('Dark'), findsOneWidget);

      // ...and the choice reached the store, not just memory.
      //
      // `tester.pump()`, not `Future.delayed(Duration.zero)`: `testWidgets`
      // runs on a fake clock, so a bare delayed future would never complete.
      // The persistence write is fire-and-forget, so a frame is what flushes
      // the microtask that lands it in the store.
      await tester.pump();
      expect(
        prefs.getString(PreferencesService.themeModeKey),
        ThemeMode.dark.name,
      );
      // Reopened the way the next launch does.
      expect(PreferencesService(prefs).readThemeMode(), ThemeMode.dark);
    });

    testWidgets('choosing System after Dark persists the system choice',
        (tester) async {
      // Seeded dark, so choosing System is a real transition. Starting from the
      // default would make the tap a no-op — `setThemeMode` returns early when
      // the mode is unchanged (pinned by `theme_mode_preference_test.dart`) —
      // and the assertion below would pass or fail for the wrong reason.
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.themeModeKey: ThemeMode.dark.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await _pumpPage(
        tester,
        const SettingsPage(),
        [
          ..._settingsOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        mode: ThemeMode.dark,
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('System default'),
      ));
      await tester.pumpAndSettle();
      await tester.pump();

      // Regression guard: "system" is written, not treated as "unset" —
      // otherwise switching back from dark would not stick across a refresh.
      expect(
        prefs.getString(PreferencesService.themeModeKey),
        ThemeMode.system.name,
      );
    });

    testWidgets('the Appearance picker touches nothing but local storage',
        (tester) async {
      // The preference is device-scoped by design. This harness overrides no
      // Firestore provider, so any write attempt would throw — reaching the
      // end with no exception IS the assertion.
      await _pumpPage(
        tester,
        const SettingsPage(),
        _settingsOverrides,
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Light'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('darkMode stays a derived getter, not a second source of truth', () {
      expect(const AppSettings().darkMode, isFalse);
      expect(const AppSettings(themeMode: ThemeMode.dark).darkMode, isTrue);
      expect(
        const AppSettings(themeMode: ThemeMode.light).darkMode,
        isFalse,
        reason: 'explicit Light is not "dark mode on"',
      );
      expect(
        // Written out rather than left to the constructor default, which is
        // `system`: with the argument dropped this line would be a byte-for-
        // byte duplicate of the bare-default case above, and the four cases
        // here are meant to read as default / dark / light / system. The
        // lint is right that the value matches the default — the explicitness
        // is the point, so it is suppressed rather than deleted.
        // ignore: avoid_redundant_argument_values
        const AppSettings(themeMode: ThemeMode.system).darkMode,
        isFalse,
        reason: 'system depends on the device, so it is not a dark choice',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ThemeMode.system
  // ═══════════════════════════════════════════════════════════

  group('ThemeMode.system resolves from the platform brightness', () {
    for (final platform in [Brightness.light, Brightness.dark]) {
      testWidgets('a ${platform.name} platform resolves the matching palette',
          (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = platform;
        addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await _pumpPage(
          tester,
          const SettingsPage(),
          _settingsOverrides,
          mode: ThemeMode.system,
        );

        expect(
          _palette(tester),
          platform == Brightness.dark ? AppColors.dark : AppColors.light,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an explicit Light overrides a dark platform', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      // `ThemeMode.light` is `_pumpPage`'s default; what this case turns on is
      // the app being told *light* while the platform reports dark.
      await _pumpPage(
        tester,
        const SettingsPage(),
        _settingsOverrides,
      );

      expect(_palette(tester), AppColors.light);
    });

    testWidgets('an explicit Dark overrides a light platform', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _pumpPage(
        tester,
        const MemberListPage(),
        _memberOverrides(viewerIsTreasurer: true),
        mode: ThemeMode.dark,
      );

      expect(_palette(tester), AppColors.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every migrated page renders under system-dark',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      for (final (Widget page, List<Override> overrides)
          in <(Widget, List<Override>)>[
        (const MemberListPage(), _memberOverrides(viewerIsTreasurer: true)),
        (const NotificationPage(), _notificationOverrides),
        (const SettingsPage(), _settingsOverrides),
        (const ProfilePage(), _settingsOverrides),
        (const CreateHousePage(), <Override>[]),
        (const JoinHousePage(), <Override>[]),
      ]) {
        await _pumpPage(tester, page, overrides, mode: ThemeMode.system);
        expect(
          _palette(tester),
          AppColors.dark,
          reason: '${page.runtimeType} did not follow the system theme',
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // No migrated surface silently stays light
  // ═══════════════════════════════════════════════════════════

  group('no migrated surface paints a light fill in dark mode', () {
    testWidgets('every page ground is dark under ThemeMode.dark',
        (tester) async {
      for (final (Widget page, List<Override> overrides)
          in <(Widget, List<Override>)>[
        (const MemberListPage(), _memberOverrides(viewerIsTreasurer: true)),
        (const NotificationPage(), _notificationOverrides),
        (const SettingsPage(), _settingsOverrides),
        (const ProfilePage(), _settingsOverrides),
        (const CreateHousePage(), <Override>[]),
        (const JoinHousePage(), <Override>[]),
      ]) {
        await _pumpPage(tester, page, overrides, mode: ThemeMode.dark);

        final scaffoldElement = tester.element(find.byType(Scaffold).first);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final fill = scaffold.backgroundColor ??
            Theme.of(scaffoldElement).scaffoldBackgroundColor;

        expect(
          fill.computeLuminance(),
          lessThan(0.2),
          reason: '${page.runtimeType} paints a light scaffold in dark mode',
        );
      }
    });

    testWidgets('no Card on the migrated pages keeps a white fill',
        (tester) async {
      // NotificationPage is deliberately absent: its rows are bare `Material`
      // widgets, not `Card`s, and their fill is asserted directly in the
      // Notifications group above.
      for (final (Widget page, List<Override> overrides)
          in <(Widget, List<Override>)>[
        (const MemberListPage(), _memberOverrides(viewerIsTreasurer: true)),
        (const SettingsPage(), _settingsOverrides),
        (const ProfilePage(), _settingsOverrides),
      ]) {
        await _pumpPage(tester, page, overrides, mode: ThemeMode.dark);

        final cards = find.byType(Card);
        expect(cards, findsWidgets,
            reason: '${page.runtimeType} should render at least one card');

        for (var i = 0; i < cards.evaluate().length; i++) {
          final card = tester.widget<Card>(cards.at(i));
          final material = tester.widget<Material>(
            find
                .descendant(of: cards.at(i), matching: find.byType(Material))
                .first,
          );
          final fill = card.color ?? material.color;
          if (fill == null) continue; // inherits the themed cardTheme
          expect(
            fill.computeLuminance(),
            lessThan(0.2),
            reason: '${page.runtimeType} card #$i kept a light fill',
          );
        }
      }
    });
  });
}
