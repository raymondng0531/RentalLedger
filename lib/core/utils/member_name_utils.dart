import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_constants.dart';

/// Resolves a house member's display name for the UI.
///
/// Used by every page that shows a member name (Dashboard Recent Activity,
/// History, Expense List, Expense Details, Deposit/Direct-Payment Details) so
/// the same person always resolves to the same name.
///
/// Priority:
/// 1. The user's profile document (`users/{userId}`) `displayName` — the
///    **authoritative** profile. When the user edits their name it is written
///    here (and to Firebase Auth) first, so this is the source of truth for
///    current names.
/// 2. The member record's stored [memberDisplayName] — a cache/backfill of the
///    profile, kept in step by profile edits. Used only when the profile is
///    missing or empty (e.g. very old records), never to override it.
/// 3. An email-derived name (the member record's email, then the profile's).
/// 4. `null` — the caller decides the final fallback label.
///
/// Display data only — never returns a Firebase UID. Historical display data
/// embedded on expense/transaction documents is NOT consulted here; those are
/// immutable audit snapshots handled by the callers.
Future<String?> resolveMemberDisplayName(
  FirebaseFirestore firestore, {
  required String userId,
  String? memberDisplayName,
  String? memberEmail,
}) async {
  String? profileName;
  String? profileEmail;
  try {
    final doc =
        await firestore.collection(FirestoreConstants.users).doc(userId).get();
    final data = doc.data();
    profileName = data?['displayName'] as String?;
    profileEmail = data?['email'] as String?;
  } catch (_) {
    // Non-critical — fall through to the member record / email fallback.
  }

  return pickDisplayName(
    profileName: profileName,
    profileEmail: profileEmail,
    memberDisplayName: memberDisplayName,
    memberEmail: memberEmail,
  );
}

/// Pure name-priority decision, separated from the Firestore read so it can be
/// unit-tested directly.
///
/// The user profile wins; the member record is a fallback cache, never a
/// source that can shadow a fresh profile edit.
@visibleForTesting
String? pickDisplayName({
  required String? profileName,
  required String? profileEmail,
  String? memberDisplayName,
  String? memberEmail,
}) {
  // 1. Authoritative user profile.
  if (profileName != null && profileName.isNotEmpty) {
    return profileName;
  }

  // 2. Member record display name (cache).
  if (memberDisplayName != null && memberDisplayName.isNotEmpty) {
    return memberDisplayName;
  }

  // 3. Email-derived name.
  final email = (memberEmail != null && memberEmail.isNotEmpty)
      ? memberEmail
      : (profileEmail != null && profileEmail.isNotEmpty ? profileEmail : null);
  final emailName = emailLocalPartName(email);
  if (emailName != null && emailName.isNotEmpty) {
    return emailName;
  }

  return null;
}

/// Derives a display name from an email's local part ("john@x.com" → "john"),
/// matching the member tile's behaviour.
String? emailLocalPartName(String? email) {
  if (email == null || email.isEmpty) return null;
  final atIndex = email.indexOf('@');
  if (atIndex <= 0) return email;
  return email.substring(0, atIndex);
}
