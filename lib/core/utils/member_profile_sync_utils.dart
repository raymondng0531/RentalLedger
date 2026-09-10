import 'package:flutter/foundation.dart';

import '../../features/members/domain/entities/house_member_entity.dart';

/// Planning for the profile → membership photo/name synchronization.
///
/// The app keeps TWO records of a person's photo:
///
/// * **Firebase Auth `photoURL`** — the canonical identity. It is what the
///   Dashboard header, the Settings header and the Profile page render, and
///   every Google sign-in rewrites it (`users/{uid}.photoUrl` follows it).
/// * **`house_members.photoUrl`** — the copy the Members list renders.
///
/// Nothing keeps the second in step with the first on its own, so a later
/// Google sign-in (or a profile edit made anywhere but the Profile page) moves
/// the Auth photo while the member row keeps the old one — the same person,
/// two different pictures. These helpers decide the writes that close that gap.
///
/// Everything here is PURE: it decides, it never writes. The data source owns
/// the Firestore I/O.

/// One planned write: which member row, and exactly which fields change.
@immutable
class MemberProfileSyncPatch {
  const MemberProfileSyncPatch({required this.memberId, required this.fields});

  /// The `house_members` document id to write.
  final String memberId;

  /// Only the fields that actually differ. Every other field on the row is
  /// therefore preserved by construction — the writer never sends a whole
  /// document, so it cannot drop `role`, `joinedAt`, `email`, `isActive`, or
  /// anything a future version adds.
  final Map<String, Object?> fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberProfileSyncPatch &&
          runtimeType == other.runtimeType &&
          memberId == other.memberId &&
          mapEquals(fields, other.fields);

  @override
  int get hashCode => Object.hash(memberId, Object.hashAllUnordered(fields.entries));

  @override
  String toString() => 'MemberProfileSyncPatch($memberId, $fields)';
}

/// Decides which of [userId]'s own member rows need a profile write, and
/// exactly which fields each needs.
///
/// [rows] may be any set of member records — the planner is the authority on
/// what may be written, so a caller that passes too much cannot cause a bad
/// write. Rows are skipped unless they are BOTH:
///
/// * **the caller's own** (`row.userId == userId`) — a profile edit may only
///   ever touch the signed-in user's own membership. Requirement, not a
///   convenience: the deployed rules permit exactly this and nothing wider.
/// * **active** (`row.isActive`) — an inactive row is the historical record of
///   a membership that ended. Its stored name/photo are what that period's
///   History renders, so rewriting them from today's profile would rewrite the
///   past. Historical rows are deliberately left alone.
///
/// A field is included only when it is supplied AND differs from what the row
/// already holds, so:
///
/// * a sync where nothing moved returns no patches — no redundant write;
/// * a supplied-empty value never blanks a stored one (an absent or empty
///   `photoUrl` means "we have no new photo", not "erase the photo").
///
/// A user active in several houses yields one patch per house, because each
/// house holds its own `house_members` row.
List<MemberProfileSyncPatch> planMemberProfileSync({
  required String userId,
  required Iterable<HouseMemberEntity> rows,
  String? displayName,
  String? photoUrl,
}) {
  final wantedName = _meaningful(displayName);
  final wantedPhoto = _meaningful(photoUrl);

  final patches = <MemberProfileSyncPatch>[];

  for (final row in rows) {
    if (row.userId != userId || !row.isActive) continue;

    final fields = <String, Object?>{};
    if (wantedName != null && wantedName != row.displayName) {
      fields['displayName'] = wantedName;
    }
    if (wantedPhoto != null && wantedPhoto != row.photoUrl) {
      fields['photoUrl'] = wantedPhoto;
    }

    // Nothing differs — writing would be a no-op that still costs a round trip
    // and still bumps nothing useful.
    if (fields.isEmpty) continue;

    patches.add(MemberProfileSyncPatch(memberId: row.memberId, fields: fields));
  }

  return patches;
}

/// Runs [sync], converting any failure into a logged `false`.
///
/// The membership photo is DISPLAY-ONLY bookkeeping. It must never be able to
/// fail a sign-in or a profile update: if the row cannot be written (offline,
/// denied by the security rules, a transient Firestore error) the user still
/// signs in and still keeps the profile they just saved — the Members tile
/// simply shows the older photo until the next successful sync.
///
/// Errors are logged rather than swallowed silently, because a rule denial
/// here is invisible in the UI and would otherwise be undiagnosable. The stack
/// trace is deliberately NOT printed: `debugPrintStack` asserts on the
/// `package:stack_trace` chains that async failures carry, which would make
/// this "safe" path throw — the exact thing it exists to prevent.
Future<bool> runMemberProfileSync(Future<void> Function() sync) async {
  try {
    await sync();
    return true;
  } catch (e) {
    debugPrint('[MemberProfileSync] membership photo sync failed (non-fatal): $e');
    return false;
  }
}

/// `null` for `null`, empty and whitespace-only strings — "no new value".
String? _meaningful(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
