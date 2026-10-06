/**
 * Cloud Functions for Rental Ledger.
 *
 * Deploy:
 *   cd functions && npm install && firebase deploy --only functions
 *
 * Responsibilities:
 *   1. sendNotificationOnCreate — push notification fan-out (below).
 *   2. The membership authorization index (syncMembershipIndex / joinHouse) —
 *      see the block comment above `syncMembershipIndex`.
 *   3. sendBillReminders — daily job that writes "bill due in 7/3/2/1 days"
 *      notifications, which sendNotificationOnCreate then pushes.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { summarizeMembership } = require('./membership_index');
const {
  DEFAULT_TIME_ZONE,
  NOTIFICATION_TYPE_BILL_REMINDER,
  reminderFor,
  reminderDocId,
  reminderCopy,
  reminderRecipients,
} = require('./bill_reminders');
admin.initializeApp();

// ─────────────────────────────────────────────────────────────
// MEMBERSHIP AUTHORIZATION INDEX
//
// Firestore rules can only `get()` a document BY PATH — they can never query a
// collection. `house_members` uses random UUID document ids, so "is this user a
// member of this house?" was not expressible, and every membership-dependent
// rule had to be left open.
//
// The fix is a second, path-addressable record:
//
//     houses/{houseId}/members/{userId}   →   { isActive, role, ... }
//
// This index is the AUTHORIZATION primitive. `house_members` remains the
// HISTORICAL record (random ids, soft deletes, multiple rows per person after a
// remove/rejoin cycle) and is never rewritten, migrated or deleted.
//
// The index is written ONLY by the Admin SDK — Firestore rules set it to
// `allow write: if false` for clients, so a client cannot manufacture, activate
// or escalate a membership. That is the whole point: the earlier gap was not
// that rules lacked a membership check, it was that any membership condition
// the rules could express was satisfiable by the attacker writing their own
// `house_members` document.
//
// ── Why a trigger rather than rewriting every workflow ──
// Leave House, Remove Member and Transfer Treasurer are completed, working
// features. Rather than converting each into a callable (a redesign), the
// trigger DERIVES the index from the `house_members` collection, so all of
// those workflows keep working exactly as they are while the index stays
// server-controlled.
// ─────────────────────────────────────────────────────────────

/** The path-addressable authorization index document for one membership. */
const memberIndexRef = (db, houseId, userId) =>
  db.doc(`houses/${houseId}/members/${userId}`);

/**
 * Recomputes ONE user's authorization state for ONE house from the underlying
 * `house_members` rows and writes the index document.
 *
 * The derivation itself lives in `membership_index.js`, shared with
 * tool/backfill_membership_index.js so the two writers cannot drift. Read that
 * file's header for why the answer is computed from the FULL row set rather
 * than copied from the row that triggered us.
 */
async function syncMemberIndex(db, houseId, userId) {
  const rows = await db
    .collection('house_members')
    .where('houseId', '==', houseId)
    .where('userId', '==', userId)
    .get();

  const summary = summarizeMembership(rows.docs.map((d) => d.data()));

  // An inactive member keeps their index document with isActive:false rather
  // than having it deleted — the document is the record that this user was
  // deauthorized, and a rejoin reactivates it in place.
  await memberIndexRef(db, houseId, userId).set(
    {
      userId,
      houseId,
      isActive: summary.isActive,
      role: summary.role,
      sourceRows: summary.totalRows,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

/**
 * Keeps the authorization index in step with `house_members` for every
 * membership workflow: join, leave, remove, transfer treasurer, rejoin.
 */
exports.syncMembershipIndex = functions.firestore
  .document('house_members/{memberId}')
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    // The row that changed tells us WHICH (house, user) pair to recompute; the
    // recomputation itself reads all of that pair's rows.
    const subject = after || before;
    if (!subject) return null;

    const houseId = subject.houseId;
    const userId = subject.userId;
    if (!houseId || !userId) {
      console.warn('house_members row without houseId/userId; skipping', change.after.id);
      return null;
    }

    // A rename of houseId/userId on an existing row would strand the old index
    // entry. The app never does this, but if it ever happened we would want the
    // old path cleared rather than left active.
    if (before && after && (before.houseId !== after.houseId || before.userId !== after.userId)) {
      await syncMemberIndex(admin.firestore(), before.houseId, before.userId);
    }

    await syncMemberIndex(admin.firestore(), houseId, userId);
    return null;
  });

/**
 * Joins a house by invite code, SERVER-SIDE.
 *
 * This had to move off the client: the old implementation found the house with
 * `houses.where('inviteCode','==',code)`, which the tightened rules forbid for
 * a non-member (that query was also the invite-code enumeration vector). The
 * invite code is validated here, with admin credentials, and the membership
 * rows are written here — so the client can never manufacture an active
 * membership.
 *
 * Creates BOTH records, in one batch so a client that immediately reads the
 * house is not racing the index:
 *   * the historical `house_members` row (same shape the client used to write,
 *     so historical member-name resolution is unaffected), and
 *   * the `houses/{houseId}/members/{uid}` index entry,
 * which the trigger would otherwise write a moment later (idempotent).
 *
 * Returns `{ houseId }`; the caller then reads the house document normally,
 * which the new rules now permit because the membership exists.
 */
exports.joinHouse = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in to join a house.',
    );
  }
  const uid = context.auth.uid;

  const inviteCode = String((data && data.inviteCode) || '')
    .trim()
    .toUpperCase();
  if (!inviteCode) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'An invite code is required.',
    );
  }

  const db = admin.firestore();

  const houseQuery = await db
    .collection('houses')
    .where('inviteCode', '==', inviteCode)
    .where('isArchived', '==', false)
    .limit(1)
    .get();

  if (houseQuery.empty) {
    throw new functions.https.HttpsError('not-found', 'Invalid invite code.');
  }

  const houseId = houseQuery.docs[0].id;

  const existing = await db
    .collection('house_members')
    .where('houseId', '==', houseId)
    .where('userId', '==', uid)
    .where('isActive', '==', true)
    .limit(1)
    .get();

  if (!existing.empty) {
    throw new functions.https.HttpsError(
      'already-exists',
      'You are already a member of this house.',
    );
  }

  // Populate display info from the user's profile, exactly as the client-side
  // helper did, so the member list shows a real name immediately.
  let displayName = null;
  let email = null;
  let photoUrl = null;
  try {
    const userSnap = await db.collection('users').doc(uid).get();
    const userData = userSnap.data();
    if (userData) {
      displayName = userData.displayName || null;
      email = userData.email || null;
      photoUrl = userData.photoUrl || null;
    }
  } catch (e) {
    // Non-critical — the row simply lacks display info.
    console.warn('joinHouse: could not read profile for', uid, e.message);
  }

  // Same shape as the client's _createMemberRecord, including a random id.
  const memberRef = db.collection('house_members').doc();
  const memberId = memberRef.id;

  const batch = db.batch();
  batch.set(memberRef, {
    memberId,
    houseId,
    userId: uid,
    role: 'Member',
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    isActive: true,
    displayName,
    email,
    photoUrl,
  });
  batch.set(
    memberIndexRef(db, houseId, uid),
    {
      userId: uid,
      houseId,
      isActive: true,
      role: 'Member',
      sourceRows: 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();

  return { houseId };
});

exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const data = snap.data();

    // The user who should receive the notification.
    const userId = data.userId;
    if (!userId) return null;

    // Look up the recipient's FCM token from their profile.
    const userSnap = await admin.firestore().collection('users').doc(userId).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) return null;

    const payload = {
      notification: {
        title: data.title || 'Rental Ledger',
        body: data.body || '',
      },
      data: {
        type: data.type || '',
        relatedId: data.relatedId || '',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      // Web push (browser / PWA): high urgency so a dozing Android phone
      // delivers it promptly, and the app icon on the system notification.
      webpush: {
        headers: { Urgency: 'high' },
        notification: {
          icon: '/icons/Icon-192.png',
          badge: '/icons/Icon-192.png',
        },
      },
      token,
    };

    try {
      await admin.messaging().send(payload);
      console.log('Notification sent to', userId);
    } catch (e) {
      console.error('FCM send error:', e.message);
      // If the token is invalid, remove it so we don't retry forever.
      if (e.code === 'messaging/registration-token-not-registered') {
        await admin.firestore().collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }

    return null;
  });

// ─────────────────────────────────────────────────────────────
// DAILY BILL REMINDERS
//
// Once a day, finds every unpaid bill due in exactly 7, 3, 2 or 1 day(s) and
// writes a `notifications` document for EVERY active member of the bill's
// house (Treasurer included). The write triggers sendNotificationOnCreate, so
// the reminder arrives both as a phone/browser push and in the in-app
// notification list.
//
// Every unpaid bill is reminded, whether or not its "Set Reminder" toggle is
// on (REQUIRE_REMINDER_FLAG = false, per the owner's choice). The day math,
// recurring-bill handling and the idempotency key live in bill_reminders.js
// (unit-tested).
// ─────────────────────────────────────────────────────────────

/** Set to true to remind only bills whose "Set Reminder" toggle is on. */
const REQUIRE_REMINDER_FLAG = false;

/**
 * The uids of every active member of a house, from the server-maintained
 * authorization index. Falls back to the house document's `treasurerId` if the
 * index has no active entries. Archived houses get no reminders.
 */
async function findActiveMemberIds(db, houseId) {
  const house = await db.collection('houses').doc(houseId).get();
  if (!house.exists) return [];

  const index = await db
    .collection(`houses/${houseId}/members`)
    .where('isActive', '==', true)
    .get();

  return reminderRecipients(house.data(), index.docs.map((d) => d.id));
}

exports.sendBillReminders = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone(DEFAULT_TIME_ZONE)
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();

    // Single-field equality — served by Firestore's automatic index.
    const unpaid = await db.collection('bills').where('isPaid', '==', false).get();

    const membersByHouse = new Map();
    let created = 0;
    let skipped = 0;

    for (const doc of unpaid.docs) {
      const bill = doc.data();
      const due = reminderFor(bill, now, { requireReminderFlag: REQUIRE_REMINDER_FLAG });
      if (!due) continue;

      if (!membersByHouse.has(bill.houseId)) {
        try {
          membersByHouse.set(bill.houseId, await findActiveMemberIds(db, bill.houseId));
        } catch (e) {
          console.error('sendBillReminders: member lookup failed', bill.houseId, e.message);
          membersByHouse.set(bill.houseId, []);
        }
      }

      const copy = reminderCopy(bill, due.daysBefore, due.dueYmd);

      for (const userId of membersByHouse.get(bill.houseId)) {
        const notificationId = reminderDocId(doc.id, due.dueYmd, due.daysBefore, userId);
        try {
          // create() fails if the doc exists → a re-run never double-sends.
          // Same shape as NotificationModel.toMap in the app.
          await db.collection('notifications').doc(notificationId).create({
            userId,
            title: copy.title,
            body: copy.body,
            type: NOTIFICATION_TYPE_BILL_REMINDER,
            isRead: false,
            relatedId: doc.id,
            createdAt: admin.firestore.Timestamp.fromDate(now),
          });
          created++;
        } catch (e) {
          // gRPC ALREADY_EXISTS = 6.
          if (e.code === 6 || e.code === 'already-exists') {
            skipped++;
          } else {
            console.error('sendBillReminders: write failed', notificationId, e.message);
          }
        }
      }
    }

    console.log(`sendBillReminders: ${created} sent, ${skipped} already sent, ` +
      `${unpaid.size} unpaid bills scanned`);
    return null;
  });
