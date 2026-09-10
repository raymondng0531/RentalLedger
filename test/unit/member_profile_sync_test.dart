import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/member_profile_sync_utils.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';

/// Regression cover for the avatar divergence found in live QA: the header
/// renders Firebase Auth `photoURL`, the Members list renders
/// `house_members.photoUrl`, and nothing kept the second in step with the
/// first — so one person showed two different pictures.
void main() {
  const uid = 'uid-raymond';
  const otherUid = 'uid-someone-else';
  const houseA = 'house-a';
  const houseB = 'house-b';

  HouseMemberEntity row({
    required String memberId,
    String houseId = houseA,
    String userId = uid,
    bool isActive = true,
    String? displayName,
    String? photoUrl,
  }) {
    return HouseMemberEntity(
      memberId: memberId,
      houseId: houseId,
      userId: userId,
      joinedAt: DateTime(2026, 3, 15),
      isActive: isActive,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  group('planMemberProfileSync — what gets written', () {
    test('a profile photo update syncs the new photo onto the active row', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          row(
            memberId: 'row-1',
            displayName: 'Raymond',
            photoUrl: 'https://old.example/avatar.jpg',
          ),
        ],
        displayName: 'Raymond Ng',
        photoUrl: 'https://new.example/avatar.jpg',
      );

      expect(patches, [
        const MemberProfileSyncPatch(
          memberId: 'row-1',
          fields: {
            'displayName': 'Raymond Ng',
            'photoUrl': 'https://new.example/avatar.jpg',
          },
        ),
      ]);
    });

    test('a Google sign-in syncs the photo ONLY, never the name', () {
      // The row's stored name is the member's own choice; the Google account
      // name must not overwrite it.
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          row(
            memberId: 'row-1',
            displayName: 'Raymo (house name)',
            photoUrl: 'https://old.example/avatar.jpg',
          ),
        ],
        // displayName deliberately omitted — a sign-in supplies no name.
        photoUrl: 'https://lh3.googleusercontent.com/new-google-photo',
      );

      expect(patches, [
        const MemberProfileSyncPatch(
          memberId: 'row-1',
          fields: {'photoUrl': 'https://lh3.googleusercontent.com/new-google-photo'},
        ),
      ]);
    });

    test('a user active in several houses gets one patch per house', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          // row-a sits in the helper's default house; row-b in the second one.
          row(memberId: 'row-a', photoUrl: 'https://old.example/a.jpg'),
          row(memberId: 'row-b', houseId: houseB, photoUrl: 'https://old.example/b.jpg'),
        ],
        photoUrl: 'https://new.example/avatar.jpg',
      );

      expect(patches, [
        const MemberProfileSyncPatch(
          memberId: 'row-a',
          fields: {'photoUrl': 'https://new.example/avatar.jpg'},
        ),
        const MemberProfileSyncPatch(
          memberId: 'row-b',
          fields: {'photoUrl': 'https://new.example/avatar.jpg'},
        ),
      ]);
    });

    test('the patch carries ONLY the changed fields', () {
      // The writer applies this map as an update, so anything absent is
      // preserved: role, joinedAt, email, isActive and houseId all survive.
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [row(memberId: 'row-1', displayName: 'Raymond', photoUrl: 'https://old.example/a.jpg')],
        displayName: 'Raymond',
        photoUrl: 'https://new.example/avatar.jpg',
      );

      expect(patches.single.fields.keys, ['photoUrl']);
    });
  });

  group('planMemberProfileSync — what is deliberately NOT written', () {
    test('an inactive historical membership is never rewritten', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          row(
            memberId: 'row-active',
            displayName: 'Old Name',
            photoUrl: 'https://old.example/a.jpg',
          ),
          row(
            memberId: 'row-historical',
            isActive: false,
            displayName: 'Name At The Time',
            photoUrl: 'https://then.example/a.jpg',
          ),
        ],
        displayName: 'New Name',
        photoUrl: 'https://new.example/avatar.jpg',
      );

      expect(patches.map((p) => p.memberId), ['row-active']);
    });

    test('a user whose ONLY rows are inactive gets no write at all', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          row(memberId: 'row-historical-1', isActive: false),
          row(memberId: 'row-historical-2', houseId: houseB, isActive: false),
        ],
        displayName: 'New Name',
        photoUrl: 'https://new.example/avatar.jpg',
      );

      expect(patches, isEmpty);
    });

    test('another user\'s rows are never touched', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          row(memberId: 'row-mine', photoUrl: 'https://old.example/a.jpg'),
          row(memberId: 'row-theirs', userId: otherUid, photoUrl: 'https://old.example/b.jpg'),
        ],
        photoUrl: 'https://new.example/avatar.jpg',
      );

      expect(patches.map((p) => p.memberId), ['row-mine']);
    });

    test('nothing is written when the photo already matches', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [
          row(
            memberId: 'row-1',
            displayName: 'Raymond',
            photoUrl: 'https://same.example/avatar.jpg',
          ),
        ],
        displayName: 'Raymond',
        photoUrl: 'https://same.example/avatar.jpg',
      );

      expect(patches, isEmpty);
    });

    test('an absent or empty photo never blanks a stored one', () {
      // `photoUrl: null` means "no new photo", not "erase the photo" — the
      // Profile page sends null whenever the user did not pick a new image.
      for (final supplied in <String?>[null, '', '   ']) {
        final patches = planMemberProfileSync(
          userId: uid,
          rows: [row(memberId: 'row-1', photoUrl: 'https://stored.example/avatar.jpg')],
          photoUrl: supplied,
        );

        expect(patches, isEmpty, reason: 'supplied=${supplied ?? 'null'}');
      }
    });

    test('a user with no member rows gets no patches', () {
      expect(
        planMemberProfileSync(
          userId: uid,
          rows: const <HouseMemberEntity>[],
          photoUrl: 'https://new.example/avatar.jpg',
        ),
        isEmpty,
      );
    });

    test('values are trimmed before comparison, so whitespace is not a change', () {
      final patches = planMemberProfileSync(
        userId: uid,
        rows: [row(memberId: 'row-1', displayName: 'Raymond')],
        displayName: '  Raymond  ',
      );

      expect(patches, isEmpty);
    });
  });

  group('runMemberProfileSync — a failed sync must never break the caller', () {
    test('reports success and completes when the sync works', () async {
      var ran = 0;

      final ok = await runMemberProfileSync(() async => ran++);

      expect(ok, isTrue);
      expect(ran, 1);
    });

    test('a throwing sync is absorbed, not propagated', () async {
      // Sign-in and profile save must still succeed when the member row cannot
      // be written (offline, a security-rule denial, a transient failure).
      var ran = 0;

      final ok = await runMemberProfileSync(() async {
        ran++;
        throw Exception('permission-denied');
      });

      expect(ok, isFalse);
      expect(ran, 1, reason: 'the sync must still have been attempted');
    });

    test('an asynchronous failure is absorbed too', () async {
      final ok = await runMemberProfileSync(
        () => Future<void>.error(StateError('offline')),
      );

      expect(ok, isFalse);
    });
  });
}
