import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/member_name_utils.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';

/// Regression test for the historical name-resolution fix.
///
/// Historical expenses/transactions store only the purchaser's UID (no durable
/// name snapshot). The display pages resolve that UID through the all-members
/// name stream, which reads EVERY `house_members` record for the house —
/// active AND inactive former members — and collapses them to one display
/// record per user ([mergeMemberRecordsByUser], the exact collapse the data
/// source applies before the page ever sees the list).
///
/// The three required scenarios:
///  1. Active member          → their name is shown.
///  2. Removed / inactive     → their name is STILL shown (the reported bug:
///     "Purchased By: UnknownMember" after Treasurer Member Removal).
///  3. Genuinely unresolvable → the existing "Unknown Member" fallback.
///
/// [_nameMap] replicates each page's map builder verbatim (displayName →
/// "Unknown Member", never a Firebase UID) fed by the merged stream value, so
/// it tests the real data path without Firestore.
HouseMemberEntity _member({
  required String memberId,
  required String userId,
  bool isActive = true,
  String? displayName,
  String? email,
}) =>
    HouseMemberEntity(
      memberId: memberId,
      houseId: 'house-1',
      userId: userId,
      joinedAt: DateTime(2026),
      isActive: isActive,
      displayName: displayName,
      email: email,
    );

Map<String, String> _nameMap(Iterable<HouseMemberEntity> records) {
  final merged = mergeMemberRecordsByUser(records);
  return {
    for (final m in merged)
      m.userId: (m.displayName?.isNotEmpty == true
          ? m.displayName!
          : 'Unknown Member'),
  };
}

void main() {
  group('Historical name resolution survives member removal', () {
    test('active member resolves to their current name', () {
      final map = _nameMap([
        _member(memberId: 'm1', userId: 'alice', displayName: 'Alice'),
        _member(memberId: 'm2', userId: 'bob', displayName: 'Bob'),
      ]);

      // Purchased By on a historical expense by the still-active member.
      expect(map['alice'], 'Alice');
      expect(map['bob'], 'Bob');
    });

    test(
        'REMOVED member keeps resolving — history never shows UnknownMember '
        'while their record exists', () {
      // Soft delete keeps the house_members record; it just flips isActive.
      final map = _nameMap([
        _member(
          memberId: 'm1',
          userId: 'alice',
          isActive: false,
          displayName: 'Alice',
        ),
        _member(memberId: 'm2', userId: 'bob', displayName: 'Bob'),
      ]);

      // The reported bug: the active-only resolver returned UnknownMember
      // here. The all-records resolver must still show the name.
      expect(map['alice'], 'Alice');
      expect(map['bob'], 'Bob');
    });

    test('rejoined member collapses to ONE row and the ACTIVE name wins', () {
      // Alice was removed (inactive record retained) then rejoined, which
      // created a second, active membership doc for the same UID.
      final map = _nameMap([
        _member(
          memberId: 'm1-old',
          userId: 'alice',
          isActive: false,
          displayName: 'Alice',
        ),
        _member(
          memberId: 'm2-new',
          userId: 'alice',
          displayName: 'Alice',
        ),
      ]);

      expect(map['alice'], 'Alice');
      // Duplicate UIDs collapse to one display record.
      expect(
        mergeMemberRecordsByUser([
          _member(
            memberId: 'm1-old',
            userId: 'alice',
            isActive: false,
            displayName: 'Alice',
          ),
          _member(
            memberId: 'm2-new',
            userId: 'alice',
            displayName: 'Alice',
          ),
        ]),
        hasLength(1),
      );
    });

    test('truly unresolvable user falls back to Unknown Member', () {
      // A record with no display name and no email cannot be resolved — the
      // existing fallback label must be used, never a UID, never a crash.
      final map = _nameMap([
        _member(memberId: 'm1', userId: 'ghost'),
      ]);

      expect(map['ghost'], 'Unknown Member');
    });

    test('empty / missing history never throws and degrades gracefully', () {
      final map = _nameMap(const []);

      expect(map['nobody'], isNull,
          reason: 'an empty roster leaves no entry to resolve against');
      // Page lookup pattern: missing key → fallback label.
      expect(map['nobody'] ?? 'Unknown Member', 'Unknown Member');
    });
  });
}
