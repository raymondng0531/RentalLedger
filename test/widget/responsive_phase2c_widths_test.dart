import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/pages/member_list_page.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/features/notifications/domain/entities/notification_entity.dart';
import 'package:rental_ledger/features/notifications/presentation/pages/notification_page.dart';
import 'package:rental_ledger/features/notifications/presentation/providers/notification_provider.dart';
import 'package:rental_ledger/features/settings/presentation/pages/profile_page.dart';
import 'package:rental_ledger/features/settings/presentation/pages/settings_page.dart';

/// Sweeps the Phase 2C responsive pages (Member List, Settings, Profile,
/// Notifications) across the widths the Web/PWA responsive work targets
/// (phones, tablets, desktops, large monitors) and fails if any page overflows
/// at any width. The breakpoints sit at 600/840/1200, so these widths exercise
/// each class: compact (360, 414), medium (600, 768, 834), expanded (840,
/// 1024), and extraLarge (1280, 1440, 1920).
///
/// Every page is pumped in its **populated** data state (member tiles + invite
/// card, all settings sections, the full profile form, grouped notification
/// tiles) so genuine layout overflows are exercised — the empty/error states
/// carry no content to overflow.
///
/// The Navigation shell's bottom bar is NOT swept here: in Phase 2C its only
/// change is capping the item row to `AppContentWidth.dashboard` via the same
/// [ResponsivePage] wrapper (no-op below 1200), and the bar's items are
/// `Expanded` so it cannot overflow at any width. It is verified by
/// `flutter analyze`, the web build, and the local visual pass.
const _widths = <double>[360, 414, 600, 768, 834, 840, 1024, 1280, 1440, 1920];

// ── Sample domain data ──────────────────────────────────────────────
// DateTimes can't be const, so these are top-level finals.

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
  treasurerId: 'user2',
  createdAt: _now,
);

// Treasurer: explicit role (not the 'Member' default).
final _treasurer = HouseMemberEntity(
  memberId: 'm2',
  houseId: 'h1',
  userId: 'user2',
  role: 'Treasurer',
  joinedAt: _now,
  displayName: 'Bob',
  email: 'bob@example.com',
);

// Regular member: role omitted (defaults to 'Member').
final _aliceMember = HouseMemberEntity(
  memberId: 'm1',
  houseId: 'h1',
  userId: 'user1',
  joinedAt: _now,
  displayName: 'Alice',
  email: 'alice@example.com',
);

// One unread "today" notification and one read one from weeks ago, so both a
// Today group and an Earlier group render. Grouping keys off DateTime.now().
final _notifications = <NotificationEntity>[
  NotificationEntity(
    notificationId: 'n1',
    userId: 'user1',
    title: 'Expense Approved',
    body: 'Your claim of RM42.50 was approved by the Treasurer.',
    type: 'Expense Approved',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  NotificationEntity(
    notificationId: 'n2',
    userId: 'user1',
    title: 'Payment Completed',
    body: 'RM150.00 was paid from the Central Account.',
    type: 'Payment Completed',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
  ),
];

// ── Provider overrides per page ─────────────────────────────────────
// Each page is given its data state directly, so no page touches Firebase.
// (ProfileData derives from currentUserProvider, so overriding that provider
// feeds both the profile header and the profile form.)

// MemberListPage is role-aware: it reads the current user to decide whether
// the viewer (as house Treasurer) sees the per-member Remove action. Override
// the user so the page never touches Firebase auth in the harness. _user is
// user1, a regular member of _house (treasurer is user2), so no remove buttons
// render — the layout exercised matches the pre-feature member view.
final _memberListOverrides = <Override>[
  currentUserProvider.overrideWith((ref) => _user),
  currentHouseProvider.overrideWith((ref) => _house),
  membersStreamProvider.overrideWith((ref) => Stream.value([_aliceMember, _treasurer])),
];

final _settingsOverrides = <Override>[
  currentUserProvider.overrideWith((ref) => _user),
  currentHouseProvider.overrideWith((ref) => _house),
];

final _profileOverrides = <Override>[
  currentUserProvider.overrideWith((ref) => _user),
  currentHouseProvider.overrideWith((ref) => _house),
  membersStreamProvider.overrideWith((ref) => Stream.value([_aliceMember, _treasurer])),
];

final _notificationsOverrides = <Override>[
  notificationsStreamProvider.overrideWith((ref) => Stream.value(_notifications)),
];

Future<void> _pumpPage(
  WidgetTester tester,
  double width,
  Widget page,
  List<Override> overrides,
) async {
  // Tall enough that lazily-built ListViews build every section, so hidden
  // overflows in deep cards are caught too.
  await tester.binding.setSurfaceSize(Size(width, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask → data state.
  await tester.pumpAndSettle(); // Finish entrance animations.
}

void main() {
  final pages = <String, (Widget, List<Override>)>{
    'Member List': (const MemberListPage(), _memberListOverrides),
    'Settings': (const SettingsPage(), _settingsOverrides),
    'Profile': (const ProfilePage(), _profileOverrides),
    'Notifications': (const NotificationPage(), _notificationsOverrides),
  };

  for (final entry in pages.entries) {
    for (final width in _widths) {
      testWidgets('${entry.key} at ${width}px', (tester) async {
        await _pumpPage(
          tester,
          width,
          entry.value.$1,
          entry.value.$2,
        );
        expect(tester.takeException(), isNull,
            reason: '${entry.key} overflowed at $width px');
      });
    }
  }
}
