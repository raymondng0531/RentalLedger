import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/pages/member_list_page.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Guards the "smallest safe UI" of Task 6 (Treasurer removes a former
/// member): the trailing Remove action is shown ONLY to the house Treasurer
/// and ONLY on regular-member tiles — never on the Treasurer's own tile.
///
/// These are pure build-state checks (no Firebase is initialised): every
/// provider the page reads is overridden, so a regular viewer renders no
/// Remove actions, and a Treasurer viewer renders exactly one — Alice's.
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

// The house Treasurer as a member record (its tile must never offer Remove).
final _treasurerMember = HouseMemberEntity(
  memberId: 'm-treasurer',
  houseId: 'h1',
  userId: 'user-treasurer',
  role: 'Treasurer',
  joinedAt: _now,
  displayName: 'Bob',
  email: 'bob@example.com',
);

// A regular member who is eligible to be removed by the Treasurer.
final _regularMember = HouseMemberEntity(
  memberId: 'm-regular',
  houseId: 'h1',
  userId: 'user-member',
  joinedAt: _now,
  displayName: 'Alice',
  email: 'alice@example.com',
);

List<Override> _overridesFor(UserEntity viewer) => [
      currentUserProvider.overrideWith((ref) => viewer),
      currentHouseProvider.overrideWith((ref) => _house),
      membersStreamProvider.overrideWith(
        (ref) => Stream.value([_regularMember, _treasurerMember]),
      ),
    ];

Future<void> _pump(
  WidgetTester tester,
  UserEntity viewer,
) async {
  // Tall surface so the lazily-built ListView renders both member sections.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overridesFor(viewer),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MemberListPage(),
      ),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask → data state.
  await tester.pumpAndSettle(); // Entrance animations.
}

void main() {
  testWidgets('a regular Member viewer sees no Remove actions', (tester) async {
    await _pump(tester, _memberUser);

    // Both member tiles render, but neither carries a remove button.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.byTooltip('Remove member'), findsNothing);
  });

  testWidgets('the Treasurer sees Remove on regular members, not on themself',
      (tester) async {
    await _pump(tester, _treasurerUser);

    // Exactly one remove action exists and it lives on the regular member's
    // (Alice's) tile, not on the Treasurer's own tile.
    expect(find.byTooltip('Remove member'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(Card, 'Alice'),
        matching: find.byTooltip('Remove member'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(Card, 'Bob'),
        matching: find.byTooltip('Remove member'),
      ),
      findsNothing,
    );
  });
}
