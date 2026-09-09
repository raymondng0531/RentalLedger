import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/pages/member_list_page.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Guards Phase 4 of the V1.0 member lifecycle UI: the viewer's own
/// membership card (Treasurer → "Transfer ownership" / Member → "Leave house")
/// and the "Make treasurer" quick action on regular-member tiles.
///
/// Business rules under test:
///  - A Treasurer sees "Transfer ownership" (enabled once another member
///    exists), never "Leave house", and a "Make treasurer" action on each
///    regular member's tile — never on their own.
///  - A Treasurer who is the only member sees "Transfer ownership" disabled.
///  - A regular Member sees only "Leave house".
///  - The transfer flow calls transferTreasurerProvider.transfer(house, from,
///    to) and the leave flow calls leaveHouseProvider.leave(house, user, false).
///
/// Pure build + notifier-recording checks: every provider the page reads is
/// overridden, so no Firebase is initialised.
final _now = DateTime(2026, 8);

final _house = HouseEntity(
  houseId: 'h1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: 'user-treasurer',
  createdAt: _now,
);

final _treasurerUser = UserEntity(
  uid: 'user-treasurer',
  email: 'bob@example.com',
  displayName: 'Bob',
  createdAt: _now,
);

final _memberUser = UserEntity(
  uid: 'user-member',
  email: 'alice@example.com',
  displayName: 'Alice',
  createdAt: _now,
);

// The house Treasurer as a member record (its tile must never offer a
// management action; the Treasurer leaves only after transferring ownership).
final _treasurerMember = HouseMemberEntity(
  memberId: 'm-treasurer',
  houseId: 'h1',
  userId: 'user-treasurer',
  role: 'Treasurer',
  joinedAt: _now,
  displayName: 'Bob',
  email: 'bob@example.com',
);

// A regular member who is eligible to be made Treasurer.
final _regularMember = HouseMemberEntity(
  memberId: 'm-regular',
  houseId: 'h1',
  userId: 'user-member',
  joinedAt: _now,
  displayName: 'Alice',
  email: 'alice@example.com',
);

/// Records the arguments passed to the real [TransferTreasurerNotifier] so a
/// flow test can assert exactly what the page handed over.
class _RecordingTransferNotifier extends TransferTreasurerNotifier {
  final List<List<String>> calls = [];

  @override
  Future<String?> transfer(
      String houseId, String fromId, String toId) async {
    calls.add([houseId, fromId, toId]);
    return null; // success
  }
}

/// Records the arguments passed to the real [LeaveHouseNotifier].
class _RecordingLeaveNotifier extends LeaveHouseNotifier {
  final List<List<Object>> calls = [];

  @override
  Future<String?> leave(
      String houseId, String userId, bool isTreasurer) async {
    calls.add([houseId, userId, isTreasurer]);
    return null; // success
  }
}

List<Override> _overridesFor({
  required UserEntity viewer,
  required List<HouseMemberEntity> members,
  TransferTreasurerNotifier? transfer,
  LeaveHouseNotifier? leave,
}) =>
    [
      currentUserProvider.overrideWith((ref) => viewer),
      currentHouseProvider.overrideWith((ref) => _house),
      membersStreamProvider.overrideWith((ref) => Stream.value(members)),
      if (transfer != null) transferTreasurerProvider.overrideWith(() => transfer),
      if (leave != null) leaveHouseProvider.overrideWith(() => leave),
    ];

Future<void> _pump(
  WidgetTester tester,
  UserEntity viewer,
  List<HouseMemberEntity> members, {
  TransferTreasurerNotifier? transfer,
  LeaveHouseNotifier? leave,
}) async {
  // Tall surface so the lazily-built ListView renders the invite-code section
  // and the membership card at the bottom.
  await tester.binding.setSurfaceSize(const Size(800, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overridesFor(
        viewer: viewer,
        members: members,
        transfer: transfer,
        leave: leave,
      ),
      child: const MaterialApp(home: MemberListPage()),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask → data state.
  await tester.pumpAndSettle(); // Entrance animations.
}

/// The FilledButton whose label is [label] — FilledButton.icon's runtime type
/// is private, so match by subtype through the ancestor finder.
Finder _filledButtonWithText(String label) =>
    find.ancestor(of: find.text(label), matching: find.bySubtype<FilledButton>());

void main() {
  group('Membership card — Treasurer viewer', () {
    testWidgets(
        'shows Transfer ownership (enabled) + Make treasurer on regular '
        'members, never Leave house', (tester) async {
      await _pump(tester, _treasurerUser, [_regularMember, _treasurerMember]);

      // The card is present with the Treasurer wording.
      expect(find.text('Your membership'), findsOneWidget);
      expect(find.text('Transfer ownership'), findsOneWidget);

      // Enabled: another active member exists to receive ownership.
      final button = tester.widget<FilledButton>(
        _filledButtonWithText('Transfer ownership'),
      );
      expect(button.onPressed, isNotNull);

      // A Treasurer leaves only after transferring, so there is no Leave.
      expect(find.text('Leave house'), findsNothing);

      // Make-treasurer appears exactly once — on the regular member's tile.
      expect(find.byTooltip('Make treasurer'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(Card, 'Alice'),
          matching: find.byTooltip('Make treasurer'),
        ),
        findsOneWidget,
      );
      // ... and never on the Treasurer's own tile.
      expect(
        find.descendant(
          of: find.widgetWithText(Card, 'Bob'),
          matching: find.byTooltip('Make treasurer'),
        ),
        findsNothing,
      );
    });

    testWidgets('disables Transfer ownership when the Treasurer is alone',
        (tester) async {
      await _pump(tester, _treasurerUser, [_treasurerMember]);

      expect(find.text('Your membership'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        _filledButtonWithText('Transfer ownership'),
      );
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('currently the only member'),
        findsOneWidget,
      );
    });
  });

  group('Membership card — regular Member viewer', () {
    testWidgets('shows Leave house and no management actions',
        (tester) async {
      await _pump(tester, _memberUser, [_treasurerMember, _regularMember]);

      expect(find.text('Your membership'), findsOneWidget);
      expect(find.text('Leave house'), findsOneWidget);
      expect(find.text('Transfer ownership'), findsNothing);
      expect(find.byTooltip('Make treasurer'), findsNothing);
      expect(find.byTooltip('Remove member'), findsNothing);
    });
  });

  group('Member lifecycle flows', () {
    testWidgets(
        'Treasurer transferring ownership calls the transfer notifier with '
        'the house id, their own id and the target id', (tester) async {
      final transfer = _RecordingTransferNotifier();
      await _pump(tester, _treasurerUser, [_regularMember, _treasurerMember],
          transfer: transfer);

      // Open the bottom-sheet target picker from the membership card.
      await tester.tap(find.text('Transfer ownership'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer to…'), findsOneWidget);

      // The regular member is listed as a target inside the sheet.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ListTile, 'Alice'),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm dialog describes the demotion, then commit.
      expect(find.text('Transfer Ownership'), findsOneWidget);
      expect(find.textContaining('regular Member'), findsOneWidget);
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(transfer.calls, [
        ['h1', 'user-treasurer', 'user-member'],
      ]);
      expect(find.text('Alice is now the Treasurer.'), findsOneWidget);
    });

    testWidgets(
        'a regular Member leaving calls the leave notifier with isTreasurer '
        'false', (tester) async {
      final leave = _RecordingLeaveNotifier();
      await _pump(tester, _memberUser, [_treasurerMember, _regularMember],
          leave: leave);

      await tester.tap(find.text('Leave house'));
      await tester.pumpAndSettle();
      expect(find.text('Leave House'), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(leave.calls, [
        ['h1', 'user-member', false],
      ]);
      expect(find.text('You left Sunset Villa.'), findsOneWidget);
    });
  });
}
