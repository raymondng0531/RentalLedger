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
} = require('firebase/firestore');

const PROJECT_ID = 'rental-ledger-rules';

// ── Fixture ids ──
const H1 = 'house-1'; // "our" house
const H2 = 'house-2'; // a different house we must never touch
const TREASURER = 'uid-treasurer';
const MEMBER = 'uid-member';
const OTHER_TREASURER = 'uid-other-treasurer';

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
    await setDoc(doc(db, 'bills', 'bill-1'), {
      houseId: H1,
      title: 'Electricity',
      amount: 120,
      isRecurring: false,
      reminderEnabled: false,
      isPaid: false,
      isActive: true,
    });
    await setDoc(doc(db, 'expenses', 'exp-1'), {
      houseId: H1,
      purchasedBy: MEMBER,
      title: 'Groceries',
      amount: 42.5,
      status: 'pending',
      paymentSource: 'personal',
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

  test('a joiner CAN create their own Member record', async () => {
    await assertSucceeds(
      setDoc(doc(as('uid-newcomer'), 'house_members', 'm-new-1'), {
        houseId: H1,
        userId: 'uid-newcomer',
        role: 'Member',
        isActive: true,
      }),
    );
  });

  test('a joiner CANNOT write a membership for somebody else', async () => {
    await assertFails(
      setDoc(doc(as('uid-newcomer'), 'house_members', 'm-new-2'), {
        houseId: H1,
        userId: MEMBER,
        role: 'Member',
        isActive: true,
      }),
    );
  });

  test('a joiner CANNOT self-assign the Treasurer role', async () => {
    await assertFails(
      setDoc(doc(as('uid-newcomer'), 'house_members', 'm-new-3'), {
        houseId: H1,
        userId: 'uid-newcomer',
        role: 'Treasurer',
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
      updateDoc(doc(as('uid-newcomer'), 'expenses', 'exp-1'), { amount: 1 }),
    );
  });

  test('the treasurer CAN advance the workflow', async () => {
    await assertSucceeds(
      updateDoc(doc(as(TREASURER), 'expenses', 'exp-1'), { status: 'approved' }),
    );
  });

  test('KNOWN GAP: a non-member can still file a pending claim in another house', async () => {
    // Documented residual, not a desired outcome. Membership is not
    // expressible in rules today: house_members uses random UUID doc ids and
    // rules can only get() a document by path, never query a collection.
    // When a path-addressable membership record exists, flip this to
    // assertFails — the assertion is inverted on purpose so the gap is
    // impossible to forget.
    await assertSucceeds(
      setDoc(doc(as('uid-outsider'), 'expenses', 'exp-outsider'), {
        houseId: H2,
        purchasedBy: 'uid-outsider',
        title: 'Misfiled',
        amount: 1,
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

  test('anyone signed in CAN still read a bill', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'bills', 'bill-1')));
  });
});

// ─────────────────────────────────────────────────────────────
describe('transactions (money movement)', () => {
  test('the treasurer CAN append a transaction', async () => {
    await assertSucceeds(
      setDoc(doc(as(TREASURER), 'transactions', 'tx-1'), {
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
// MEASURED SECURITY POSTURE — the evidence base for the membership
// design decision.
//
// Every assertion in this block records what the rules allow TODAY for a
// signed-in user who belongs to NO house (OUTSIDER). These are NOT desired
// outcomes. They are asserted as successes on purpose, so the exposure is
// measured rather than assumed, and so each one becomes the acceptance test
// for the fix: when a path-addressable membership record exists, these flip
// to assertFails.
//
// Read together they show WHY a membership check on `expenses create` alone
// would be security theatre: the outsider can already read every house's id
// and invite code and can forge an active membership record for any house.
// The fix has to close that loop, not just add a condition to one rule.
describe('MEASURED POSTURE — what a house-less signed-in user can do', () => {
  const OUTSIDER = 'uid-outsider';

  test('an outsider CAN list EVERY house_members record (no filter)', async () => {
    // `allow read` grants list as well as get, and no rule requires the query
    // to be scoped — so one unfiltered query returns every house's roster
    // (names, emails, photo URLs) and, with it, every houseId in the system.
    const snap = await getDocs(collection(as(OUTSIDER), 'house_members'));
    assert.ok(
      snap.size >= 3,
      `expected the full roster to be readable, saw ${snap.size} docs`,
    );
    assert.ok(snap.docs.every((d) => typeof d.data().houseId === 'string'));
  });

  test('an outsider CAN read another house document, invite code included', async () => {
    // The invite code is the join secret, and it is readable by anyone signed
    // in who knows (or learned, above) the houseId.
    const snap = await getDoc(doc(as(OUTSIDER), 'houses', H2));
    assert.strictEqual(snap.data().inviteCode, 'ZZ99YY');
  });

  test('an outsider CAN read another house\'s expenses', async () => {
    await assertSucceeds(getDoc(doc(as(OUTSIDER), 'expenses', 'exp-1')));
  });

  test('an outsider CAN list the transactions collection', async () => {
    // Financial history is readable collection-wide, not just by document.
    const snap = await getDocs(collection(as(OUTSIDER), 'transactions'));
    assert.ok(Array.isArray(snap.docs));
  });

  test('an outsider CAN forge an ACTIVE membership in a house never joined', async () => {
    // THE CRUX. Membership create only checks userId == auth.uid and a role,
    // so a house-less user can write themselves an active Member record for
    // any houseId — including one they just harvested from the roster leak
    // above. This is why a membership *check* alone closes nothing: the
    // attacker can satisfy it. Closing the gap requires membership to be
    // asserted by something the client cannot write.
    await assertSucceeds(
      setDoc(doc(as(OUTSIDER), 'house_members', 'm-forged'), {
        houseId: H2,
        userId: OUTSIDER,
        role: 'Member',
        isActive: true,
      }),
    );
  });

  test('an outsider CAN flip the reminder flag on another house\'s bill', async () => {
    // Confirms the reported bills residual — the member-facing reminder
    // toggle is pinned to one field, but pinned for EVERYONE, not just
    // members. No money moves and no data is destroyed.
    await assertSucceeds(
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
});
