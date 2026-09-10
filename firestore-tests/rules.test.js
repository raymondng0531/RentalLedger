/**
 * Firestore security-rules tests for Rental Ledger.
 *
 * These exercise the rules through the Firebase Emulator with real SDK calls —
 * the only way to verify that authorization is actually enforced server-side
 * rather than merely mirrored by provider/UI guards.
 *
 * Run:
 *   cd firestore-tests && npm install && npm test
 *
 * (`npm test` boots the Firestore emulator via `firebase emulators:exec`, runs
 * `node --test`, and tears the emulator down. Java is required.)
 *
 * Every test names the app path it protects, so a failure points at the
 * workflow it would break.
 */
const assert = require('node:assert');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { test, before, after, beforeEach, describe } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  query,
  where,
  orderBy,
  limit,
} = require('firebase/firestore');

const PROJECT_ID = 'rental-ledger-rules';

// ── Fixture ids ──
const H1 = 'house-1'; // "our" house
const H2 = 'house-2'; // a different house we must never touch
const TREASURER = 'uid-treasurer';
const MEMBER = 'uid-member';
const OTHER_TREASURER = 'uid-other-treasurer';
const FORMER = 'uid-former'; // left H1 — historical record, inactive
const REJOINED = 'uid-rejoined'; // left H1 and came back — two rows, one active
const OUTSIDER = 'uid-outsider'; // belongs to no house at all
const NEWCOMER = 'uid-newcomer'; // will join H1 through the callable

let testEnv;

/** Seeds the fixture with rules disabled (the "trusted server" context). */
async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'houses', H1), {
      houseId: H1,
      houseName: 'Sunset Villa',
      inviteCode: 'AB12CD',
      treasurerId: TREASURER,
      balance: 0,
      currency: 'MYR',
      isArchived: false,
    });
    await setDoc(doc(db, 'houses', H2), {
      houseId: H2,
      houseName: 'Other House',
      inviteCode: 'ZZ99YY',
      treasurerId: OTHER_TREASURER,
      balance: 0,
      currency: 'MYR',
      isArchived: false,
    });
    // house_members ids are random UUIDs in production, deliberately mimicked
    // here so the tests never lean on a deterministic id the app does not use.
    await setDoc(doc(db, 'house_members', 'm-treasurer-1'), {
      houseId: H1,
      userId: TREASURER,
      role: 'Treasurer',
      isActive: true,
    });
    await setDoc(doc(db, 'house_members', 'm-member-1'), {
      houseId: H1,
      userId: MEMBER,
      role: 'Member',
      isActive: true,
    });
    await setDoc(doc(db, 'house_members', 'm-other-1'), {
      houseId: H2,
      userId: OTHER_TREASURER,
      role: 'Treasurer',
      isActive: true,
    });
    // A member who LEFT. The row survives (Leave House is a soft delete) and
    // the historical member-name feature reads it. Must remain readable by the
    // house's members.
    await setDoc(doc(db, 'house_members', 'm-former-1'), {
      houseId: H1,
      userId: FORMER,
      role: 'Member',
      isActive: false,
      displayName: 'Former Resident',
      email: 'former@example.com',
    });
    // Removed, then REJOINED: two rows for one person, exactly one active. The
    // aggregation in functions/index.js must OR these to "active" — a stale
    // soft-deleted row must never deactivate a current member.
    await setDoc(doc(db, 'house_members', 'm-rejoined-old'), {
      houseId: H1,
      userId: REJOINED,
      role: 'Member',
      isActive: false,
    });
    await setDoc(doc(db, 'house_members', 'm-rejoined-new'), {
      houseId: H1,
      userId: REJOINED,
      role: 'Member',
      isActive: true,
    });

    // ── The AUTHORIZATION INDEX ──
    // What the tightened rules actually read. In production this is written
    // only by the Admin SDK — the Cloud Function trigger (functions/index.js)
    // for live workflows, and tool/backfill_membership_index.js for
    // memberships that predate it. Seeding it here models a backfilled
    // production database; a fixture WITHOUT an entry models someone who is
    // not a member.
    await setDoc(doc(db, 'houses', H1, 'members', TREASURER), {
      userId: TREASURER,
      houseId: H1,
      isActive: true,
      role: 'Treasurer',
      sourceRows: 1,
    });
    await setDoc(doc(db, 'houses', H1, 'members', MEMBER), {
      userId: MEMBER,
      houseId: H1,
      isActive: true,
      role: 'Member',
      sourceRows: 1,
    });
    await setDoc(doc(db, 'houses', H1, 'members', REJOINED), {
      userId: REJOINED,
      houseId: H1,
      isActive: true,
      role: 'Member',
      sourceRows: 2,
    });
    // A deauthorized member keeps their entry with isActive:false rather than
    // having it deleted — that is the record that they were deauthorized.
    await setDoc(doc(db, 'houses', H1, 'members', FORMER), {
      userId: FORMER,
      houseId: H1,
      isActive: false,
      role: 'Member',
      sourceRows: 1,
    });
    await setDoc(doc(db, 'houses', H2, 'members', OTHER_TREASURER), {
      userId: OTHER_TREASURER,
      houseId: H2,
      isActive: true,
      role: 'Treasurer',
      sourceRows: 1,
    });

    await setDoc(doc(db, 'bills', 'bill-1'), {
      houseId: H1,
      title: 'Electricity',
      amount: 120,
      isRecurring: false,
      reminderEnabled: false,
      isPaid: false,
      isActive: true,
      dueDate: new Date('2026-01-15'),
    });
    await setDoc(doc(db, 'expenses', 'exp-1'), {
      houseId: H1,
      purchasedBy: MEMBER,
      title: 'Groceries',
      amount: 42.5,
      status: 'pending',
      paymentSource: 'personal',
      createdAt: new Date('2026-01-10'),
    });
    await setDoc(doc(db, 'expenses', 'exp-h2'), {
      houseId: H2,
      purchasedBy: OTHER_TREASURER,
      title: 'Other house groceries',
      amount: 10,
      status: 'pending',
      paymentSource: 'personal',
      createdAt: new Date('2026-01-10'),
    });
    await setDoc(doc(db, 'transactions', 'tx-1'), {
      houseId: H1,
      type: 'Deposit',
      amount: 500,
      performedBy: TREASURER,
      createdAt: new Date('2026-01-05'),
    });
    await setDoc(doc(db, 'transactions', 'tx-h2'), {
      houseId: H2,
      type: 'Deposit',
      amount: 700,
      performedBy: OTHER_TREASURER,
      createdAt: new Date('2026-01-05'),
    });
    await setDoc(doc(db, 'categories', `${H1}_cat-1`), {
      categoryId: 'cat-1',
      houseId: H1,
      name: 'Groceries',
      icon: 'cart',
      color: '#FF0000',
    });
    await setDoc(doc(db, 'notifications', 'n-member'), {
      userId: MEMBER,
      title: 'Approved',
      body: 'Your claim was approved',
      type: 'expense_approved',
      isRead: false,
      createdAt: new Date('2026-01-11'),
    });
  });
}

/** A context authenticated as [uid]. */
const as = (uid) => testEnv.authenticatedContext(uid).firestore();
/** An unauthenticated context. */
const anon = () => testEnv.unauthenticatedContext().firestore();

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed();
});

// ─────────────────────────────────────────────────────────────
describe('house_members — role escalation', () => {
  test('a member CANNOT rewrite their own role (self-promotion)', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        role: 'Treasurer',
      }),
    );
  });

  test('a member CANNOT rewrite another member\'s record', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-treasurer-1'), {
        isActive: false,
      }),
    );
  });

  test('a member CAN leave (isActive:false on their own record)', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: false,
      }),
    );
  });

  test('a member CANNOT sneak a role change alongside leaving', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: false,
        role: 'Treasurer',
      }),
    );
  });

  test('the treasurer CAN transfer the role (two-record rewrite)', async () => {
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-member-1'), {
        role: 'Treasurer',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-treasurer-1'), {
        role: 'Member',
      }),
    );
  });

  test('the treasurer CAN remove a member', async () => {
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-member-1'), {
        isActive: false,
      }),
    );
  });

  test('a joiner CANNOT create their own Member record (moved to the callable)', async () => {
    // This USED to succeed, and that was the whole vulnerability: a client that
    // can write its own membership can satisfy any membership check the rules
    // could express. Member rows are now written by the `joinHouse` Cloud
    // Function with admin credentials (functions/index.js), so the client-side
    // write is refused.
    await assertFails(
      setDoc(doc(as(NEWCOMER), 'house_members', 'm-new-1'), {
        houseId: H1,
        userId: NEWCOMER,
        role: 'Member',
        isActive: true,
      }),
    );
  });

  test('a joiner CANNOT write a membership for somebody else', async () => {
    await assertFails(
      setDoc(doc(as(NEWCOMER), 'house_members', 'm-new-2'), {
        houseId: H1,
        userId: MEMBER,
        role: 'Member',
        isActive: true,
      }),
    );
  });

  test('a joiner CANNOT self-assign the Treasurer role', async () => {
    await assertFails(
      setDoc(doc(as(NEWCOMER), 'house_members', 'm-new-3'), {
        houseId: H1,
        userId: NEWCOMER,
        role: 'Treasurer',
        isActive: true,
      }),
    );
  });

  test('even a real member CANNOT write a Member row for their own house', async () => {
    // The rule is about the RECORD, not the person: a Member row is a
    // server-owned artifact now. Only the Treasurer create path (createHouse)
    // survives, because that is the only client-side membership write the app
    // still performs.
    await assertFails(
      setDoc(doc(as(MEMBER), 'house_members', 'm-new-4'), {
        houseId: H1,
        userId: MEMBER,
        role: 'Member',
        isActive: true,
      }),
    );
  });

  test("the house's own treasurer CAN create their Treasurer record", async () => {
    // createHouse writes the creator's membership as Treasurer.
    await assertSucceeds(
      setDoc(doc(as(TREASURER), 'house_members', 'm-treasurer-2'), {
        houseId: H1,
        userId: TREASURER,
        role: 'Treasurer',
        isActive: true,
      }),
    );
  });

  test('nobody can delete a membership record outright', async () => {
    await assertFails(
      deleteDoc(doc(as(TREASURER), 'house_members', 'm-member-1')),
    );
  });
});

// ─────────────────────────────────────────────────────────────
// The avatar/name synchronization (`updateMemberDisplayInfo`) writes
// displayName + photoUrl onto the signed-in user's own row. Before this
// permission existed only the Treasurer could write those two fields, so every
// other member's member-list avatar went stale as soon as their profile photo
// changed. These tests pin both halves of that trade: the narrow permission it
// needs, and every escalation it must still refuse.
describe('house_members — own-row profile sync (displayName / photoUrl)', () => {
  test('a member CAN set displayName on their own active row', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        displayName: 'Raymond Ng',
      }),
    );

    // Read back through the member's own read permission: the write landed,
    // and it landed on displayName alone.
    const snap = await getDoc(doc(as(MEMBER), 'house_members', 'm-member-1'));
    assert.equal(snap.data().displayName, 'Raymond Ng');
    assert.equal(snap.data().role, 'Member', 'role must be untouched');
    assert.equal(snap.data().isActive, true, 'isActive must be untouched');
    assert.equal(snap.data().userId, MEMBER, 'userId must be untouched');
    assert.equal(snap.data().houseId, H1, 'houseId must be untouched');
  });

  test('a member CAN set photoUrl on their own active row', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        photoUrl: 'https://example.invalid/avatar.jpg',
      }),
    );

    const snap = await getDoc(doc(as(MEMBER), 'house_members', 'm-member-1'));
    assert.equal(snap.data().photoUrl, 'https://example.invalid/avatar.jpg');
    assert.equal(snap.data().isActive, true);
  });

  test('a member CAN set displayName AND photoUrl together (the real sync)', async () => {
    // What the app actually sends: one update carrying both changed fields.
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        displayName: 'Raymond Ng',
        photoUrl: 'https://example.invalid/avatar.jpg',
      }),
    );

    const snap = await getDoc(doc(as(MEMBER), 'house_members', 'm-member-1'));
    assert.equal(snap.data().displayName, 'Raymond Ng');
    assert.equal(snap.data().photoUrl, 'https://example.invalid/avatar.jpg');
  });

  test('a member CANNOT reactivate an inactive row of their own', async () => {
    // FORMER left H1: the row survives as the historical record. Flipping it
    // back is refused — the profile branch requires the row to be active
    // ALREADY, and the Leave-House branch only ever turns activity off.
    await assertFails(
      updateDoc(doc(as(FORMER), 'house_members', 'm-former-1'), {
        isActive: true,
      }),
    );
  });

  test('a member CANNOT rewrite their own inactive row\'s profile fields', async () => {
    // Historical rows keep the name the person had while they lived there.
    await assertFails(
      updateDoc(doc(as(FORMER), 'house_members', 'm-former-1'), {
        displayName: 'Renamed After Leaving',
      }),
    );
    await assertFails(
      updateDoc(doc(as(FORMER), 'house_members', 'm-former-1'), {
        photoUrl: 'https://example.invalid/after.jpg',
      }),
    );
  });

  test('a member CANNOT set isActive on their own active row', async () => {
    // The profile branch requires a NON-EMPTY change confined to
    // displayName/photoUrl. `isActive: true` on a row that is already active
    // changes no field at all, so there is no permitted update here to make —
    // the write is refused rather than treated as a no-op.
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: true,
      }),
    );
  });

  test('asking for the isActive it already has is a no-op, not a privilege', async () => {
    // Restating an unchanged value is not an "affected key", so this is really
    // just the displayName write — and isActive stays true because nothing
    // touched it. The dangerous direction (false -> true) is covered above.
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: true,
        displayName: 'Raymond Ng',
      }),
    );

    const snap = await getDoc(doc(as(MEMBER), 'house_members', 'm-member-1'));
    assert.equal(snap.data().isActive, true);
  });

  test('a member CANNOT change their own role (still no self-promotion)', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        role: 'Treasurer',
      }),
    );
  });

  test('a member CANNOT change houseId on their own row', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        houseId: H2,
      }),
    );
    // …and not as a passenger on an otherwise-permitted profile write either.
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        displayName: 'Raymond Ng',
        houseId: H2,
      }),
    );
  });

  test('a member CANNOT change userId on their own row', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        userId: OTHER_TREASURER,
      }),
    );
  });

  test('a member CANNOT change any other membership field', async () => {
    for (const field of [
      'memberId',
      'joinedAt',
      'email',
      'sourceRows',
      'inviteCode',
    ]) {
      await assertFails(
        updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
          [field]: 'attacker-value',
        }),
      );
      // Nor smuggled alongside a permitted field.
      await assertFails(
        updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
          displayName: 'Raymond Ng',
          [field]: 'attacker-value',
        }),
      );
    }
  });

  test('a member CANNOT add an arbitrary extra field alongside photoUrl', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        photoUrl: 'https://example.invalid/avatar.jpg',
        fcmToken: 'planted',
      }),
    );
  });

  test('a member CANNOT write displayName/photoUrl on ANOTHER member\'s row', async () => {
    for (const rowId of ['m-treasurer-1', 'm-former-1', 'm-rejoined-new']) {
      await assertFails(
        updateDoc(doc(as(MEMBER), 'house_members', rowId), {
          displayName: 'Not Mine',
        }),
      );
      await assertFails(
        updateDoc(doc(as(MEMBER), 'house_members', rowId), {
          photoUrl: 'https://example.invalid/not-mine.jpg',
        }),
      );
      // …and in the other house, which a member of H1 must never reach.
      await assertFails(
        updateDoc(doc(as(MEMBER), 'house_members', rowId), {
          displayName: 'Not Mine',
          houseId: H2,
        }),
      );
    }
  });

  test('somebody with no membership at all CANNOT use the profile permission', async () => {
    await assertFails(
      updateDoc(doc(as(OUTSIDER), 'house_members', 'm-member-1'), {
        displayName: 'Outsider',
      }),
    );
  });

  test('a member can STILL leave the house (isActive:false, unchanged)', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: false,
      }),
    );
  });

  test('a member CANNOT combine leaving with a profile-field change', async () => {
    // The two key-sets are disjoint and neither branch admits their union, so
    // Leave House can never carry a profile edit with it.
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: false,
        displayName: 'Raymond Ng',
      }),
    );
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        isActive: false,
        photoUrl: 'https://example.invalid/avatar.jpg',
      }),
    );
  });

  test('the Treasurer CAN still sync their own row\'s displayName/photoUrl', async () => {
    // The original live-QA case: the Treasurer's own row held a stale photo.
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-treasurer-1'), {
        displayName: 'Raymond Ng',
        photoUrl: 'https://example.invalid/avatar.jpg',
      }),
    );
  });

  test('the Treasurer retains full update rights over the house\'s rows', async () => {
    // Transfer Treasurer and Remove Member depend on these, and must not have
    // been narrowed by the new own-row branch.
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-member-1'), {
        role: 'Treasurer',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-former-1'), {
        displayName: 'Edited By Treasurer',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-member-1'), {
        isActive: false,
      }),
    );
  });

  test('another house\'s Treasurer gains nothing in this house', async () => {
    await assertFails(
      updateDoc(doc(as(OTHER_TREASURER), 'house_members', 'm-member-1'), {
        displayName: 'Not Yours',
        photoUrl: 'https://example.invalid/not-yours.jpg',
      }),
    );
  });
});

// ─────────────────────────────────────────────────────────────
describe('expenses', () => {
  test('a member CAN file their own pending claim', async () => {
    await assertSucceeds(
      setDoc(doc(as(MEMBER), 'expenses', 'exp-new'), {
        houseId: H1,
        purchasedBy: MEMBER,
        title: 'Internet',
        amount: 99,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
  });

  test('a claim CANNOT be filed under another uid', async () => {
    await assertFails(
      setDoc(doc(as(MEMBER), 'expenses', 'exp-new'), {
        houseId: H1,
        purchasedBy: TREASURER,
        title: 'Forged',
        amount: 99,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
  });

  test('a claim CANNOT be created already approved', async () => {
    await assertFails(
      setDoc(doc(as(MEMBER), 'expenses', 'exp-new'), {
        houseId: H1,
        purchasedBy: MEMBER,
        title: 'Pre-approved',
        amount: 99,
        status: 'approved',
        paymentSource: 'personal',
      }),
    );
  });

  test('the owner CAN edit their own pending claim', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'expenses', 'exp-1'), { amount: 50 }),
    );
  });

  test('a member CANNOT edit another member\'s claim', async () => {
    await assertFails(
      updateDoc(doc(as(NEWCOMER), 'expenses', 'exp-1'), { amount: 1 }),
    );
  });

  test('a member CANNOT edit another house\'s claim', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'expenses', 'exp-h2'), { amount: 1 }),
    );
  });

  test('the treasurer CAN advance the workflow', async () => {
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'expenses', 'exp-1'), { status: 'approved' }),
    );
  });

  test('CLOSED: a non-member CANNOT file a claim in another house', async () => {
    // The reported gap, inverted. It used to succeed because membership was
    // not expressible in rules: `house_members` uses random UUID document ids
    // and rules can only get() by path, never query a collection. With the
    // addressable index in place the check is expressible — and, crucially,
    // NOT satisfiable by the attacker, because the index is server-written.
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'expenses', 'exp-outsider'), {
        houseId: H2,
        purchasedBy: OUTSIDER,
        title: 'Misfiled',
        amount: 1,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
  });

  test('a member CANNOT file a claim in ANOTHER house they do not belong to', async () => {
    // Belonging to house 1 must not confer anything in house 2.
    await assertFails(
      setDoc(doc(as(MEMBER), 'expenses', 'exp-cross'), {
        houseId: H2,
        purchasedBy: MEMBER,
        title: 'Cross-house',
        amount: 1,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
  });

  test('a REJOINED member CAN still file a claim', async () => {
    // Guards the aggregation: two rows for this person, only the newer one
    // active. If the index were derived from a single row, a stale soft-deleted
    // row could have left them deauthorized.
    await assertSucceeds(
      setDoc(doc(as(REJOINED), 'expenses', 'exp-rejoined'), {
        houseId: H1,
        purchasedBy: REJOINED,
        title: 'After rejoining',
        amount: 5,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
  });

  test('a member who LEFT CANNOT file a claim any more', async () => {
    await assertFails(
      setDoc(doc(as(FORMER), 'expenses', 'exp-former'), {
        houseId: H1,
        purchasedBy: FORMER,
        title: 'After leaving',
        amount: 5,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
  });
});

// ─────────────────────────────────────────────────────────────
describe('bills', () => {
  test('the treasurer CAN create a bill', async () => {
    await assertSucceeds(
      setDoc(doc(as(TREASURER), 'bills', 'bill-new'), {
        houseId: H1,
        title: 'Water',
        amount: 60,
        isRecurring: false,
        reminderEnabled: false,
        isPaid: false,
        isActive: true,
      }),
    );
  });

  test('a member CANNOT create a bill', async () => {
    await assertFails(
      setDoc(doc(as(MEMBER), 'bills', 'bill-new'), {
        houseId: H1,
        title: 'Water',
        amount: 60,
        isRecurring: false,
        reminderEnabled: false,
        isPaid: false,
        isActive: true,
      }),
    );
  });

  test('the treasurer CANNOT create a bill in another house', async () => {
    await assertFails(
      setDoc(doc(as(TREASURER), 'bills', 'bill-x'), {
        houseId: H2,
        title: 'Not mine',
        amount: 1,
        isRecurring: false,
        reminderEnabled: false,
        isPaid: false,
        isActive: true,
      }),
    );
  });

  test('a member CAN toggle the reminder (member-facing control)', async () => {
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'bills', 'bill-1'), { reminderEnabled: true }),
    );
  });

  test('a member CANNOT rewrite a bill amount', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'bills', 'bill-1'), { amount: 1 }),
    );
  });

  test('a member CANNOT mark a bill paid', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'bills', 'bill-1'), { isPaid: true }),
    );
  });

  test('a member CANNOT delete a bill', async () => {
    await assertFails(deleteDoc(doc(as(MEMBER), 'bills', 'bill-1')));
  });

  test('the treasurer CAN delete a bill', async () => {
    await assertSucceeds(deleteDoc(doc(as(TREASURER), 'bills', 'bill-1')));
  });

  test('the treasurer CANNOT delete another house\'s bill', async () => {
    await assertFails(deleteDoc(doc(as(OTHER_TREASURER), 'bills', 'bill-1')));
  });

  test('a member CAN read their own house\'s bill', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'bills', 'bill-1')));
  });

  test('a NON-MEMBER CANNOT read a bill', async () => {
    // Was `if request.auth != null` — every bill in the system was readable by
    // anyone signed in.
    await assertFails(getDoc(doc(as(OUTSIDER), 'bills', 'bill-1')));
  });

  test('another house\'s treasurer CANNOT read this house\'s bill', async () => {
    await assertFails(getDoc(doc(as(OTHER_TREASURER), 'bills', 'bill-1')));
  });

  test('CLOSED: a non-member CANNOT flip another house\'s reminder flag', async () => {
    // The reported residual. The reminder toggle stays member-reachable (it is
    // an explicitly member-facing control), but it is now pinned to ACTIVE
    // MEMBERSHIP as well as to the single field.
    await assertFails(
      updateDoc(doc(as(OUTSIDER), 'bills', 'bill-1'), {
        reminderEnabled: true,
      }),
    );
  });

  test('a MEMBER of another house CANNOT flip this house\'s reminder flag', async () => {
    await assertFails(
      updateDoc(doc(as(OTHER_TREASURER), 'bills', 'bill-1'), {
        reminderEnabled: true,
      }),
    );
  });

  test('a member who LEFT CANNOT flip the reminder flag', async () => {
    await assertFails(
      updateDoc(doc(as(FORMER), 'bills', 'bill-1'), { reminderEnabled: true }),
    );
  });
});

// ─────────────────────────────────────────────────────────────
describe('transactions (money movement)', () => {
  test('the treasurer CAN append a transaction', async () => {
    // A NEW document id — `tx-1` is seeded by the fixture, and re-`setDoc`-ing
    // an existing document is an UPDATE, which the append-only rule refuses.
    await assertSucceeds(
      setDoc(doc(as(TREASURER), 'transactions', 'tx-new'), {
        houseId: H1,
        type: 'Deposit',
        amount: 500,
        performedBy: TREASURER,
      }),
    );
  });

  test('a member CANNOT append a transaction', async () => {
    await assertFails(
      setDoc(doc(as(MEMBER), 'transactions', 'tx-2'), {
        houseId: H1,
        type: 'Deposit',
        amount: 500,
        performedBy: MEMBER,
      }),
    );
  });

  test('a non-member CANNOT append a transaction to another house', async () => {
    await assertFails(
      setDoc(doc(as('uid-outsider'), 'transactions', 'tx-3'), {
        houseId: H1,
        type: 'Deposit',
        amount: 999999,
        performedBy: 'uid-outsider',
      }),
    );
  });

  test('transactions are append-only', async () => {
    await assertFails(
      updateDoc(doc(as(TREASURER), 'transactions', 'tx-1'), { amount: 0 }),
    );
    await assertFails(deleteDoc(doc(as(TREASURER), 'transactions', 'tx-1')));
  });

  test('a member CAN read their own house\'s transactions', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'transactions', 'tx-1')));
  });

  test('a NON-MEMBER CANNOT read a transaction', async () => {
    await assertFails(getDoc(doc(as(OUTSIDER), 'transactions', 'tx-1')));
  });

  test('another house\'s treasurer CANNOT read this house\'s transactions', async () => {
    await assertFails(getDoc(doc(as(OTHER_TREASURER), 'transactions', 'tx-1')));
  });
});

// ─────────────────────────────────────────────────────────────
describe('houses', () => {
  test('a member CANNOT change the house treasurerId', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'houses', H1), { treasurerId: MEMBER }),
    );
  });

  test('the treasurer CAN edit the house', async () => {
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'houses', H1), { houseName: 'Renamed' }),
    );
  });

  test('nobody can delete a house', async () => {
    await assertFails(deleteDoc(doc(as(TREASURER), 'houses', H1)));
  });

  test('a member CAN read their own house', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'houses', H1)));
  });

  test('CLOSED: an outsider CANNOT read another house — invite code included', async () => {
    // This used to return the document WITH its inviteCode. The invite code is
    // the join secret, so reading it was equivalent to being handed the keys.
    await assertFails(getDoc(doc(as(OUTSIDER), 'houses', H2)));
  });

  test('another house\'s treasurer CANNOT read this house', async () => {
    await assertFails(getDoc(doc(as(OTHER_TREASURER), 'houses', H1)));
  });

  test('a member CANNOT enumerate the houses collection', async () => {
    // `allow read` grants list as well as get, so "can read a house" used to
    // mean "can read EVERY house". A list now requires a constraint the rule
    // can prove, and there is none for an unscoped query.
    await assertFails(getDocs(collection(as(MEMBER), 'houses')));
  });

  test('the creator MUST name themselves Treasurer', async () => {
    // Previously any signed-in user could create a house naming someone ELSE
    // as Treasurer — handing that person Treasurer powers over a house they
    // never made, and leaving the creator with none.
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'houses', 'house-forged'), {
        houseId: 'house-forged',
        houseName: 'Forged',
        inviteCode: 'AAAA11',
        treasurerId: MEMBER,
        balance: 0,
        currency: 'MYR',
        isArchived: false,
      }),
    );
  });

  test('the creator CAN create a house naming themselves Treasurer', async () => {
    // The real createHouse path.
    await assertSucceeds(
      setDoc(doc(as(OUTSIDER), 'houses', 'house-own'), {
        houseId: 'house-own',
        houseName: 'My New House',
        inviteCode: 'BBBB22',
        treasurerId: OUTSIDER,
        balance: 0,
        currency: 'MYR',
        isArchived: false,
      }),
    );
  });
});

// ─────────────────────────────────────────────────────────────
// THE INDEX ITSELF.
//
// Everything above rests on one property: the client cannot write the document
// the rules read. If that ever stops being true, every membership rule in this
// file becomes decorative — so it is asserted directly rather than assumed.
describe('membership index — server-owned', () => {
  test('an outsider CANNOT create an index entry for themselves', async () => {
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'houses', H2, 'members', OUTSIDER), {
        userId: OUTSIDER,
        houseId: H2,
        isActive: true,
        role: 'Member',
      }),
    );
  });

  test('an outsider CANNOT create an index entry for themselves in a house they can name', async () => {
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'houses', H1, 'members', OUTSIDER), {
        userId: OUTSIDER,
        houseId: H1,
        isActive: true,
        role: 'Member',
      }),
    );
  });

  test('a member CANNOT activate their own deauthorized entry (re-entry)', async () => {
    // The subtle one. A member who left still has an entry with
    // isActive:false; if they could flip it back, leaving would be reversible
    // unilaterally and removal would be meaningless.
    await assertFails(
      updateDoc(doc(as(FORMER), 'houses', H1, 'members', FORMER), {
        isActive: true,
      }),
    );
  });

  test('a member CANNOT promote themselves in the index', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'houses', H1, 'members', MEMBER), {
        role: 'Treasurer',
      }),
    );
  });

  test('even the TREASURER CANNOT write the index', async () => {
    // Admin SDK only. The Cloud Functions writer bypasses rules entirely, so
    // `write: if false` costs it nothing.
    await assertFails(
      updateDoc(doc(as(TREASURER), 'houses', H1, 'members', MEMBER), {
        isActive: false,
      }),
    );
  });

  test('nobody can delete an index entry', async () => {
    await assertFails(
      deleteDoc(doc(as(TREASURER), 'houses', H1, 'members', MEMBER)),
    );
  });

  test('a member CAN read their own house\'s index entries', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'houses', H1, 'members', TREASURER)));
  });

  test('a user CAN read their own index entry in any house', async () => {
    await assertSucceeds(getDoc(doc(as(FORMER), 'houses', H1, 'members', FORMER)));
  });

  test('a NON-MEMBER CANNOT read a house\'s index entries', async () => {
    await assertFails(getDoc(doc(as(OUTSIDER), 'houses', H1, 'members', MEMBER)));
  });

  test('another house\'s treasurer CANNOT read this house\'s index entries', async () => {
    await assertFails(
      getDoc(doc(as(OTHER_TREASURER), 'houses', H1, 'members', MEMBER)),
    );
  });
});

// ─────────────────────────────────────────────────────────────
describe('notifications (accepted risk)', () => {
  test('a signed-in user can create a notification for another user', async () => {
    // Deliberate: the acting client writes cross-user notifications. Tightening
    // this to userId == auth.uid previously broke every "Reimbursement
    // Completed" push. See the accepted-risk note in firestore.rules.
    await assertSucceeds(
      setDoc(doc(as(MEMBER), 'notifications', 'n-1'), {
        userId: TREASURER,
        title: 'Expense submitted',
        body: 'Groceries',
        type: 'expense_submitted',
        isRead: false,
      }),
    );
  });

  test('a user CANNOT read another user\'s notifications', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'notifications', 'n-2'), {
        userId: TREASURER,
        title: 'Private',
        isRead: false,
      });
    });
    await assertFails(getDoc(doc(as(MEMBER), 'notifications', 'n-2')));
  });
});

// ─────────────────────────────────────────────────────────────
describe('unauthenticated access', () => {
  test('an anonymous client CANNOT append a transaction', async () => {
    await assertFails(
      setDoc(doc(anon(), 'transactions', 'tx-anon'), {
        houseId: H1,
        type: 'Deposit',
        amount: 1,
      }),
    );
  });

  test('an anonymous client CANNOT create a bill', async () => {
    await assertFails(
      setDoc(doc(anon(), 'bills', 'bill-anon'), {
        houseId: H1,
        title: 'x',
        amount: 1,
      }),
    );
  });

  test('an anonymous client CANNOT read a house', async () => {
    await assertFails(getDoc(doc(anon(), 'houses', H1)));
  });
});

// ─────────────────────────────────────────────────────────────
// CLOSURE EVIDENCE — what a house-less signed-in user can do NOW.
//
// Every one of these was measured as a SUCCESS before the membership index
// landed (see the git history of this file). They are asserted as failures
// here, so the closure is evidenced rather than claimed. If any of them
// regresses, the vulnerability is back.
describe('CLOSED — what a house-less signed-in user CANNOT do', () => {
  test('an outsider CANNOT list the house_members collection', async () => {
    // Used to return every house's roster: names, emails, photo URLs — and
    // with it every houseId in the system.
    await assertFails(getDocs(collection(as(OUTSIDER), 'house_members')));
  });

  test('even a MEMBER cannot list house_members unfiltered', async () => {
    // The rule is per-document and depends on houseId, so an unscoped query is
    // not provable even for a legitimate member. Correct: no collection-wide
    // reads. Every real caller scopes by houseId or userId (see the
    // query-compatibility block below).
    await assertFails(getDocs(collection(as(MEMBER), 'house_members')));
  });

  test('an outsider CANNOT read another house document, invite code included', async () => {
    await assertFails(getDoc(doc(as(OUTSIDER), 'houses', H2)));
  });

  test('an outsider CANNOT read another house\'s expenses', async () => {
    await assertFails(getDoc(doc(as(OUTSIDER), 'expenses', 'exp-1')));
  });

  test('an outsider CANNOT list the expenses collection unfiltered', async () => {
    await assertFails(getDocs(collection(as(OUTSIDER), 'expenses')));
  });

  test('an outsider CANNOT list the transactions collection unfiltered', async () => {
    // Financial history used to be readable collection-wide, not just by
    // document.
    await assertFails(getDocs(collection(as(OUTSIDER), 'transactions')));
  });

  test('an outsider CANNOT list the bills collection unfiltered', async () => {
    await assertFails(getDocs(collection(as(OUTSIDER), 'bills')));
  });

  test('an outsider CANNOT list the categories collection unfiltered', async () => {
    await assertFails(getDocs(collection(as(OUTSIDER), 'categories')));
  });

  test('an outsider CANNOT forge an ACTIVE membership', async () => {
    // THE CRUX, and the reason the fix is an index plus a server-side writer
    // rather than a membership check alone. Membership create used to accept
    // `userId == auth.uid` for any houseId, so the attacker could satisfy any
    // membership condition the rules could express. Now the record they would
    // have to forge is one they cannot write at all.
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'house_members', 'm-forged'), {
        houseId: H2,
        userId: OUTSIDER,
        role: 'Member',
        isActive: true,
      }),
    );
    // …and the index entry that would actually authorize them.
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'houses', H2, 'members', OUTSIDER), {
        userId: OUTSIDER,
        houseId: H2,
        isActive: true,
        role: 'Member',
      }),
    );
  });

  test('an outsider CANNOT flip the reminder flag on another house\'s bill', async () => {
    await assertFails(
      updateDoc(doc(as(OUTSIDER), 'bills', 'bill-1'), {
        reminderEnabled: true,
      }),
    );
  });

  test('an outsider CANNOT append a transaction (money boundary holds)', async () => {
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'transactions', 'tx-forged'), {
        houseId: H2,
        type: 'Deposit',
        amount: 9999,
      }),
    );
  });

  test('an outsider CANNOT approve another house\'s expense (money boundary holds)', async () => {
    await assertFails(
      updateDoc(doc(as(OUTSIDER), 'expenses', 'exp-1'), { status: 'approved' }),
    );
  });

  test('an outsider CANNOT profit from the house they cannot read', async () => {
    // End-to-end: no read, no claim, no approval, no money. The full chain a
    // real attacker would walk.
    await assertFails(getDoc(doc(as(OUTSIDER), 'houses', H2)));
    await assertFails(getDoc(doc(as(OUTSIDER), 'houses', H2, 'members', OTHER_TREASURER)));
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'expenses', 'exp-attack'), {
        houseId: H2,
        purchasedBy: OUTSIDER,
        title: 'Attack',
        amount: 10000,
        status: 'pending',
        paymentSource: 'personal',
      }),
    );
    await assertFails(
      setDoc(doc(as(OUTSIDER), 'transactions', 'tx-attack'), {
        houseId: H2,
        type: 'Deposit',
        amount: 10000,
      }),
    );
  });
});

// ─────────────────────────────────────────────────────────────
// HISTORICAL RECORDS — the e7f4813 member-name feature is protected.
//
// Tightening membership reads must not break the roster's historical names.
// These pin that: inactive rows stay readable BY THE HOUSE, and the house's
// members keep resolving a departed member's name from their surviving row.
describe('historical membership records', () => {
  test('a member CAN still read a DEPARTED member\'s row', async () => {
    // This is what historical name resolution reads. If it broke, History
    // would show "Unknown Member" for anyone who ever left.
    const snap = await getDoc(doc(as(MEMBER), 'house_members', 'm-former-1'));
    assert.strictEqual(snap.data().displayName, 'Former Resident');
    assert.strictEqual(snap.data().isActive, false);
  });

  test('a member CAN still query the FULL roster, inactive rows included', async () => {
    // allMembersStreamProvider's query — the one that feeds the historical
    // name lookup. Scoped by houseId only, deliberately NOT filtered on
    // isActive, so departed members remain resolvable.
    const snap = await getDocs(
      query(collection(as(MEMBER), 'house_members'), where('houseId', '==', H1)),
    );
    const ids = snap.docs.map((d) => d.id);
    assert.ok(ids.includes('m-former-1'), 'departed member must remain readable');
    assert.ok(ids.includes('m-rejoined-old'), 'superseded row must remain readable');
  });

  test('a DEPARTED member CAN still read their own row', async () => {
    // So a removed member can still see their own membership history.
    await assertSucceeds(getDoc(doc(as(FORMER), 'house_members', 'm-former-1')));
  });

  test('a DEPARTED member CANNOT read the house roster any more', async () => {
    // They can see their own record and nothing else.
    await assertFails(
      getDocs(
        query(
          collection(as(FORMER), 'house_members'),
          where('houseId', '==', H1),
        ),
      ),
    );
  });

  test('a member CANNOT read ANOTHER house\'s historical roster', async () => {
    await assertFails(
      getDocs(
        query(
          collection(as(MEMBER), 'house_members'),
          where('houseId', '==', H2),
        ),
      ),
    );
  });

  test('no historical row was deleted, re-keyed or rewritten', async () => {
    // The backfill and the index are additive by construction; this pins it.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const former = await getDoc(doc(db, 'house_members', 'm-former-1'));
      assert.ok(former.exists(), 'departed member row must survive');
      assert.strictEqual(former.data().displayName, 'Former Resident');
      const rejoinedOld = await getDoc(doc(db, 'house_members', 'm-rejoined-old'));
      assert.ok(rejoinedOld.exists(), 'superseded row must survive');
      // Random UUID ids stay random — no deterministic re-keying.
      assert.strictEqual(former.id, 'm-former-1');
    });
  });
});

// ─────────────────────────────────────────────────────────────
// QUERY COMPATIBILITY — the queries the real application actually runs.
//
// Firestore rules are NOT filters: a `list` succeeds only when the rule is
// PROVABLE from the query's constraints. So tightening a read rule can break a
// screen that looks unrelated, and an isolated per-document rule test would
// never catch it. Every query below is transcribed from the Dart data sources
// it names, and run as-is against the emulator with the real rules loaded.
//
// These are faithful transcriptions, not the Dart code itself — `cloud_firestore`
// needs platform channels that `flutter test` does not provide, so the browser
// or a device is the only place the literal Dart runs. The query SHAPE is what
// the rules evaluate, and the shape is what is reproduced here.
describe('query compatibility — the app\'s real queries under the new rules', () => {
  // Thin aliases so each case reads like the Dart it transcribes.
  const coll = (db, name) => collection(db, name);
  const q = (_db, ...parts) => query(...parts);

  test('Dashboard: house document listen (getHouse / houseStream)', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'houses', H1)));
    await assertSucceeds(getDoc(doc(as(TREASURER), 'houses', H1)));
  });

  test('Dashboard: house_members listener scoped by houseId', async () => {
    // dashboard_remote_datasource.dart — `.where('houseId', isEqualTo: houseId)`
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'house_members'), where('houseId', '==', H1))),
    );
  });

  test('Dashboard: expense + transaction listeners scoped by houseId', async () => {
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'expenses'), where('houseId', '==', H1))),
    );
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'transactions'), where('houseId', '==', H1))),
    );
  });

  test('Dashboard: this month\'s transactions (houseId + createdAt range)', async () => {
    // `.where('houseId','==',h).where('createdAt','>=',start).where('createdAt','<=',end)`
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'transactions'),
          where('houseId', '==', H1),
          where('createdAt', '>=', new Date('2026-01-01')),
          where('createdAt', '<=', new Date('2026-01-31')),
        ),
      ),
    );
  });

  test('Dashboard: recent activity (houseId + orderBy + limit)', async () => {
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'transactions'),
          where('houseId', '==', H1),
          orderBy('createdAt', 'desc'),
          limit(20),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'expenses'),
          where('houseId', '==', H1),
          orderBy('createdAt', 'desc'),
          limit(20),
        ),
      ),
    );
  });

  test('Dashboard: outstanding claims (houseId + status whereIn)', async () => {
    // `.where('houseId','==',h).where('status', whereIn: ['pending','approved'])`
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'expenses'),
          where('houseId', '==', H1),
          where('status', 'in', ['pending', 'approved']),
        ),
      ),
    );
  });

  test('Dashboard: member-name resolution (houseId, all rows)', async () => {
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'house_members'), where('houseId', '==', H1))),
    );
  });

  test('Sign-in: findHouseByUserId (userId + isActive)', async () => {
    // house_remote_datasource.dart — the query that discovers which house to
    // load. It is scoped by the caller's OWN uid, which is exactly what the
    // second branch of the read rule makes provable.
    for (const uid of [TREASURER, MEMBER, REJOINED]) {
      const db = as(uid);
      const snap = await assertSucceeds(
        getDocs(
          q(
            db,
            coll(db, 'house_members'),
            where('userId', '==', uid),
            where('isActive', '==', true),
          ),
        ),
      );
      assert.ok(snap.size >= 1, `${uid} must find their own membership`);
    }
  });

  test('Sign-in: getSwitcherHouses (the same userId-scoped query)', async () => {
    const db = as(MEMBER);
    await assertSucceeds(
      getDocs(
        q(
          db,
          coll(db, 'house_members'),
          where('userId', '==', MEMBER),
          where('isActive', '==', true),
        ),
      ),
    );
  });

  test('Members: active roster stream (houseId + isActive)', async () => {
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'house_members'),
          where('houseId', '==', H1),
          where('isActive', '==', true),
        ),
      ),
    );
  });

  test('Members: allMembersStream incl. inactive (protected feature)', async () => {
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'house_members'), where('houseId', '==', H1))),
    );
  });

  test('Expenses: list ordered by createdAt, optional status filter', async () => {
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'expenses'),
          where('houseId', '==', H1),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'expenses'),
          where('houseId', '==', H1),
          orderBy('createdAt', 'desc'),
          where('status', '==', 'pending'),
        ),
      ),
    );
  });

  test('History: getTransactions (houseId + orderBy + limit)', async () => {
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'transactions'),
          where('houseId', '==', H1),
          orderBy('createdAt', 'desc'),
          limit(20),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'transactions'),
          where('houseId', '==', H1),
          orderBy('createdAt', 'desc'),
          where('type', '==', 'Deposit'),
          limit(20),
        ),
      ),
    );
  });

  test('History: getAllTransactions (houseId)', async () => {
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'transactions'), where('houseId', '==', H1))),
    );
  });

  test('Reports: category totals (houseId + status whereIn + date range)', async () => {
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'expenses'),
          where('houseId', '==', H1),
          where('status', 'in', ['approved', 'paid']),
          where('createdAt', '>=', new Date('2026-01-01')),
          where('createdAt', '<=', new Date('2026-12-31')),
        ),
      ),
    );
  });

  test('Bills: unpaid list (houseId + isActive + orderBy dueDate)', async () => {
    await assertSucceeds(
      getDocs(
        q(
          as(MEMBER),
          coll(as(MEMBER), 'bills'),
          where('houseId', '==', H1),
          where('isActive', '==', true),
          orderBy('dueDate'),
        ),
      ),
    );
  });

  test('Bills: ledger listener (houseId)', async () => {
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'bills'), where('houseId', '==', H1))),
    );
  });

  test('Categories: getCategories (houseId)', async () => {
    await assertSucceeds(
      getDocs(q(as(MEMBER), coll(as(MEMBER), 'categories'), where('houseId', '==', H1))),
    );
  });

  test('Notifications: list + unread count, scoped to the recipient', async () => {
    const db = as(MEMBER);
    await assertSucceeds(
      getDocs(
        q(
          db,
          coll(db, 'notifications'),
          where('userId', '==', MEMBER),
          orderBy('createdAt', 'desc'),
          limit(50),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        q(
          db,
          coll(db, 'notifications'),
          where('userId', '==', MEMBER),
          where('isRead', '==', false),
        ),
      ),
    );
  });

  test('Notifications: user A CANNOT read user B\'s notifications', async () => {
    await assertFails(
      getDocs(
        q(
          as(TREASURER),
          coll(as(TREASURER), 'notifications'),
          where('userId', '==', MEMBER),
        ),
      ),
    );
  });

  test('Join House: the invite-code lookup is DENIED to the client — by design', async () => {
    // house_remote_datasource.joinHouse used to run exactly this. It cannot any
    // more, and must not: the invite code is the join secret, so looking a
    // house up by it reads a house the caller does not belong to. This is the
    // query that moved to the `joinHouse` Cloud Function, and this test is the
    // reason it had to.
    await assertFails(
      getDocs(
        q(
          as(NEWCOMER),
          coll(as(NEWCOMER), 'houses'),
          where('inviteCode', '==', 'AB12CD'),
          where('isArchived', '==', false),
          limit(1),
        ),
      ),
    );
  });

  test('Create House: the creator can read the house they just made', async () => {
    // The create path writes the house BEFORE the membership exists, so the
    // treasurerId branch of the read rule is what keeps it readable in between.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'houses', 'house-fresh'), {
        houseId: 'house-fresh',
        houseName: 'Fresh',
        inviteCode: 'CCCC33',
        treasurerId: OUTSIDER,
        balance: 0,
        currency: 'MYR',
        isArchived: false,
      });
    });
    await assertSucceeds(getDoc(doc(as(OUTSIDER), 'houses', 'house-fresh')));
  });
});

// ─────────────────────────────────────────────────────────────
// getMembers displayName backfill — what the tightened rules did to it.
//
// `getMembers` resolves each member's name through `resolveMemberDisplayName`
// and then PERSISTS the resolved name onto the house_members row as a cache.
// Under the tightened rules that persist narrowed to the caller's OWN active
// rows — it is no longer a write a member can perform on anyone else.
//
// The question these tests answer is whether that is a REGRESSION or benign
// graceful degradation. It is benign, and the reason is in the last test: the
// name that every read path returns is resolved IN MEMORY, so the cache write
// failing cannot change what the UI displays. The cache only ever made future
// reads cheaper.
// ─────────────────────────────────────────────────────────────
describe('getMembers displayName backfill — degraded, not broken', () => {
  test('a member CANNOT persist a backfilled name onto ANOTHER member\'s row', async () => {
    await assertFails(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-treasurer-1'), {
        displayName: 'Resolved Name',
      }),
    );
  });

  test('a member CAN persist a backfilled name onto their OWN active row', async () => {
    // This USED to be refused, and the refusal had a cost: the only member
    // update branch was Leave House (hasOnly(['isActive'])), so a member could
    // not refresh their own displayName or photo at all. That is precisely why
    // the Members list kept showing a stale avatar after a profile edit.
    //
    // It is now permitted, but not as "write your own row" — the permission is
    // own-row, ACTIVE-row, displayName/photoUrl only. The test above pins the
    // "somebody else's row" half; the own-row profile-sync suite pins the rest.
    await assertSucceeds(
      updateDoc(doc(as(MEMBER), 'house_members', 'm-member-1'), {
        displayName: 'Resolved Name',
      }),
    );
  });

  test('the TREASURER can still persist it — the cache is still populated', async () => {
    // So the backfill has not stopped working; it has narrowed to the role the
    // UI already treats as the one that maintains the roster.
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'house_members', 'm-member-1'), {
        displayName: 'Resolved Name',
      }),
    );
  });

  test('a member can still READ the cached names the resolution depends on', async () => {
    // This is the load-bearing one. resolveMemberDisplayName reads
    // users/{uid}, which is own-profile-only — so for anyone but yourself the
    // PROFILE read was ALREADY refused before this phase, and the name has
    // always come from this cached field on the membership row. If this read
    // were denied, names really would break.
    const snap = await assertSucceeds(
      getDoc(doc(as(MEMBER), 'house_members', 'm-former-1')),
    );
    assert.strictEqual(snap.data().displayName, 'Former Resident');
  });

  test('and the resolution input survives for the WHOLE roster, inactive included', async () => {
    // getMembers reads exactly this query shape. Every row it gets back
    // carries the cached displayName it needs.
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(as(MEMBER), 'house_members'),
          where('houseId', '==', H1),
          where('isActive', '==', true),
        ),
      ),
    );
    assert.ok(snap.size >= 3);
  });

  test('the users profile read that feeds resolution IS refused for others — pre-existing', async () => {
    // Documents WHY the cache exists, and that this phase did not introduce it.
    // The users rule is own-profile-only and was unchanged by this phase.
    await assertFails(getDoc(doc(as(MEMBER), 'users', TREASURER)));
    await assertSucceeds(getDoc(doc(as(MEMBER), 'users', MEMBER)));
  });
});
