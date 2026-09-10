/**
 * Self-test for the membership-index backfill.
 *
 * The backfill is what authorizes every EXISTING member on the day the
 * tightened rules land. If it gets a case wrong, real people are locked out of
 * their own house — or, worse, somebody who left keeps their access. So it is
 * tested against a real Firestore emulator rather than trusted.
 *
 * The two properties that matter most, and are asserted directly:
 *   * IDENTITY-PRESERVING — `house_members` is never written, deleted or
 *     re-keyed. Random ids survive; historical rows survive.
 *   * IDEMPOTENT — running it twice writes the same entries, and running it
 *     after the Cloud Function has already written an entry agrees with it.
 *
 * Runs against the Firestore emulator. The TEST seeds data via admin (which
 * bypasses rules — models production, where these rows already exist).
 *
 *   cd tool && npm install && npm test
 */
'use strict';

const assert = require('node:assert');
const { test, before, after, beforeEach, describe } = require('node:test');

const admin = require('firebase-admin');

const { backfillMembershipIndex, BATCH_LIMIT } = require('./backfill_membership_index');
// The SAME rule the live Cloud Function applies — imported here to assert the
// two writers agree, which is the drift this whole arrangement exists to stop.
const { summarizeMembership } = require('../functions/membership_index');

const PROJECT_ID = 'rental-ledger-backfill';

let db;

/** Writes a house document so the index does not point at a missing house. */
async function seedHouse(houseId, extra = {}) {
  await db.collection('houses').doc(houseId).set({
    houseId,
    houseName: `House ${houseId}`,
    inviteCode: 'CODE01',
    treasurerId: 'uid-treasurer',
    balance: 0,
    currency: 'MYR',
    isArchived: false,
    ...extra,
  });
}

/** Writes one `house_members` row, keyed by an explicit (random-looking) id. */
async function seedMember(memberId, houseId, userId, extra = {}) {
  await db.collection('house_members').doc(memberId).set({
    memberId,
    houseId,
    userId,
    role: 'Member',
    isActive: true,
    ...extra,
  });
}

/** The index entry for one (house, user) pair, or null. */
async function indexEntry(houseId, userId) {
  const snap = await db.doc(`houses/${houseId}/members/${userId}`).get();
  return snap.exists ? snap.data() : null;
}

/** Every index path that currently exists. */
async function allIndexPaths() {
  const houses = await db.collection('houses').get();
  const paths = [];
  for (const house of houses.docs) {
    const members = await db.collection('houses').doc(house.id).collection('members').get();
    for (const m of members.docs) paths.push(`${house.id}/${m.id}`);
  }
  return paths.sort();
}

function entryFor(report, houseId, userId) {
  const entry = report.entries.find(
    (e) => e.houseId === houseId && e.userId === userId,
  );
  assert.ok(entry, `no report entry for ${houseId}/${userId}`);
  return entry;
}

before(async () => {
  admin.initializeApp({ projectId: PROJECT_ID });
  db = admin.firestore();
});

after(async () => {
  await admin.app().delete();
});

beforeEach(async () => {
  // RECURSIVE delete, not a loop over documents. Deleting a house document
  // does NOT delete its `members` subcollection — the entries are merely
  // orphaned, and re-creating a house of the same id makes them visible again.
  // A flat delete here would leak index entries between tests and quietly
  // invalidate every "nothing was written" assertion below.
  await db.recursiveDelete(db.collection('houses'));
  await db.recursiveDelete(db.collection('house_members'));
});

describe('backfill — what it derives', () => {
  test('an active member gets an ACTIVE index entry', async () => {
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');

    const report = await backfillMembershipIndex(db, { apply: true });

    const entry = await indexEntry('h1', 'uid-a');
    assert.strictEqual(entry.isActive, true);
    assert.strictEqual(entry.role, 'Member');
    assert.strictEqual(entry.houseId, 'h1');
    assert.strictEqual(entry.userId, 'uid-a');
    assert.strictEqual(report.summary.written, 1);
  });

  test('a treasurer gets the Treasurer role', async () => {
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-t', { role: 'Treasurer' });

    await backfillMembershipIndex(db, { apply: true });

    assert.strictEqual((await indexEntry('h1', 'uid-t')).role, 'Treasurer');
  });

  test('a departed member gets an INACTIVE entry, not no entry', async () => {
    // The document is the record that they were deauthorized; deleting it
    // would make "removed" indistinguishable from "never existed".
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-gone', { isActive: false });

    await backfillMembershipIndex(db, { apply: true });

    const entry = await indexEntry('h1', 'uid-gone');
    assert.ok(entry, 'the entry must exist');
    assert.strictEqual(entry.isActive, false);
  });

  test('a removed-then-rejoined member is ACTIVE', async () => {
    // The case that makes "copy the last written row" wrong: two rows, the
    // newer active, the older a soft-deleted leftover.
    await seedHouse('h1');
    await seedMember('m-old', 'h1', 'uid-back', { isActive: false });
    await seedMember('m-new', 'h1', 'uid-back', { isActive: true });

    await backfillMembershipIndex(db, { apply: true });

    const entry = await indexEntry('h1', 'uid-back');
    assert.strictEqual(entry.isActive, true);
    assert.strictEqual(entry.sourceRows, 2);
  });

  test('a legacy row with no isActive field is treated as ACTIVE', async () => {
    // Otherwise every pre-existing member is locked out the moment the rules
    // land — the failure mode this backfill exists to prevent.
    await seedHouse('h1');
    await db.collection('house_members').doc('m-legacy').set({
      houseId: 'h1',
      userId: 'uid-legacy',
      role: 'Member',
    });

    await backfillMembershipIndex(db, { apply: true });

    assert.strictEqual((await indexEntry('h1', 'uid-legacy')).isActive, true);
  });

  test('members of different houses get separate entries', async () => {
    await seedHouse('h1');
    await seedHouse('h2');
    await seedMember('m-1', 'h1', 'uid-a');
    await seedMember('m-2', 'h2', 'uid-b');
    await seedMember('m-3', 'h2', 'uid-a', { isActive: false });

    await backfillMembershipIndex(db, { apply: true });

    // Same person, two houses, two independent states.
    assert.strictEqual((await indexEntry('h1', 'uid-a')).isActive, true);
    assert.strictEqual((await indexEntry('h2', 'uid-a')).isActive, false);
    assert.strictEqual((await indexEntry('h2', 'uid-b')).isActive, true);
  });

  test('the same user in two houses is not collapsed into one entry', async () => {
    await seedHouse('h1');
    await seedHouse('h2');
    await seedMember('m-1', 'h1', 'uid-multi');
    await seedMember('m-2', 'h2', 'uid-multi');

    const report = await backfillMembershipIndex(db, { apply: true });

    assert.deepStrictEqual(await allIndexPaths(), [
      'h1/uid-multi',
      'h2/uid-multi',
    ]);
    assert.strictEqual(report.summary.membershipPairs, 2);
  });
});

describe('backfill — dry run', () => {
  test('by default it writes NOTHING', async () => {
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');

    const report = await backfillMembershipIndex(db);

    assert.strictEqual(report.summary.applied, false);
    assert.strictEqual(report.summary.written, 0);
    assert.deepStrictEqual(await allIndexPaths(), []);
    // …but it still REPORTS what it would do, which is the point of a dry run.
    assert.strictEqual(report.summary.membershipPairs, 1);
    assert.strictEqual(entryFor(report, 'h1', 'uid-a').isActive, true);
  });

  test('the dry run and the apply agree on the same data', async () => {
    // A dry run that predicts something other than what --apply does is worse
    // than no dry run, because it is trusted.
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');
    await seedMember('m-2', 'h1', 'uid-gone', { isActive: false });
    await seedMember('m-3', 'h1', 'uid-back', { isActive: false });
    await seedMember('m-4', 'h1', 'uid-back', { isActive: true });

    const dry = await backfillMembershipIndex(db);
    await backfillMembershipIndex(db, { apply: true });
    const applied = await backfillMembershipIndex(db);

    assert.deepStrictEqual(dry.entries, applied.entries);
  });
});

describe('backfill — identity preservation', () => {
  test('house_members is byte-for-byte unchanged', async () => {
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');
    await seedMember('m-random-uuid-looking-id', 'h1', 'uid-gone', {
      isActive: false,
      displayName: 'Former Resident',
      email: 'former@example.com',
    });

    const before = (await db.collection('house_members').get()).docs
      .map((d) => ({ id: d.id, data: d.data() }))
      .sort((a, b) => a.id.localeCompare(b.id));

    await backfillMembershipIndex(db, { apply: true });

    const after = (await db.collection('house_members').get()).docs
      .map((d) => ({ id: d.id, data: d.data() }))
      .sort((a, b) => a.id.localeCompare(b.id));

    assert.deepStrictEqual(after, before, 'house_members must not be touched');
  });

  test('random document ids are NOT re-keyed to anything deterministic', async () => {
    // The rejected design was a deterministic {houseId}_{userId} rewrite. This
    // pins that the chosen design does not quietly do it.
    await seedHouse('h1');
    await seedMember('m-9f3a2b7c', 'h1', 'uid-a');

    await backfillMembershipIndex(db, { apply: true });

    const ids = (await db.collection('house_members').get()).docs.map((d) => d.id);
    assert.deepStrictEqual(ids, ['m-9f3a2b7c']);
    assert.ok(!ids.includes('h1_uid-a'));
  });

  test('nothing is ever deleted', async () => {
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a', { isActive: false });

    await backfillMembershipIndex(db, { apply: true });

    const count = (await db.collection('house_members').get()).size;
    assert.strictEqual(count, 1);
  });
});

describe('backfill — idempotence', () => {
  test('running it twice produces the same entries', async () => {
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');
    await seedMember('m-2', 'h1', 'uid-gone', { isActive: false });

    await backfillMembershipIndex(db, { apply: true });
    const first = await allIndexPaths();
    const firstEntries = (await backfillMembershipIndex(db)).entries;

    await backfillMembershipIndex(db, { apply: true });
    const second = await allIndexPaths();
    const secondEntries = (await backfillMembershipIndex(db)).entries;

    assert.deepStrictEqual(second, first, 'no duplicate index documents');
    assert.deepStrictEqual(secondEntries, firstEntries);
  });

  test('it does not fight the Cloud Function writer', async () => {
    // The live trigger may have written an entry already. The backfill must
    // agree with it, not overwrite it with a different answer — that is what
    // sharing summarizeMembership buys.
    await seedHouse('h1');
    await seedMember('m-old', 'h1', 'uid-back', { isActive: false });
    await seedMember('m-new', 'h1', 'uid-back', { isActive: true });

    // What the Cloud Function's syncMemberIndex would have written.
    const rows = (await db.collection('house_members').get()).docs
      .map((d) => d.data())
      .filter((d) => d.houseId === 'h1' && d.userId === 'uid-back');
    const expected = summarizeMembership(rows);
    await db.doc('houses/h1/members/uid-back').set({
      userId: 'uid-back',
      houseId: 'h1',
      isActive: expected.isActive,
      role: expected.role,
      sourceRows: expected.totalRows,
    });

    const report = await backfillMembershipIndex(db, { apply: true });
    const entry = await indexEntry('h1', 'uid-back');

    assert.strictEqual(entry.isActive, expected.isActive);
    assert.strictEqual(entry.role, expected.role);
    assert.strictEqual(entryFor(report, 'h1', 'uid-back').isActive, true);
  });

  test('it repairs an index entry that drifted from the row set', async () => {
    // Self-healing: if the index ever says something the rows do not support,
    // a rerun corrects it.
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');
    await db.doc('houses/h1/members/uid-a').set({
      userId: 'uid-a',
      houseId: 'h1',
      isActive: false,
      role: 'Member',
      sourceRows: 1,
    });

    await backfillMembershipIndex(db, { apply: true });

    assert.strictEqual((await indexEntry('h1', 'uid-a')).isActive, true);
  });
});

describe('backfill — anomalies are reported, not repaired', () => {
  test('a row with no houseId/userId is reported and skipped', async () => {
    await seedHouse('h1');
    await db.collection('house_members').doc('m-broken').set({
      role: 'Member',
      isActive: true,
    });

    const report = await backfillMembershipIndex(db, { apply: true });

    assert.strictEqual(report.summary.rowsWithoutKeys, 1);
    assert.strictEqual(report.summary.written, 0);
    assert.ok(report.anomalies.some((a) => a.kind === 'row-missing-keys'));
    // The broken row is left exactly where it is.
    assert.ok((await db.collection('house_members').doc('m-broken').get()).exists);
  });

  test('two simultaneously-active rows for one person are reported', async () => {
    // The app never creates this, so it means a partial failure somewhere.
    // Reported — NOT deduplicated, because deleting a membership row is not
    // this tool's decision to make.
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-dup', { isActive: true });
    await seedMember('m-2', 'h1', 'uid-dup', { isActive: true });

    const report = await backfillMembershipIndex(db, { apply: true });

    const anomaly = report.anomalies.find(
      (a) => a.kind === 'multiple-active-rows',
    );
    assert.ok(anomaly, 'the duplicate must be reported');
    assert.strictEqual(anomaly.activeRows, 2);
    assert.deepStrictEqual(anomaly.memberIds.sort(), ['m-1', 'm-2']);
    // Both rows survive.
    assert.strictEqual((await db.collection('house_members').get()).size, 2);
  });

  test('an active member of a missing house is reported', async () => {
    // The index entry would be written under a house that does not exist.
    await seedMember('m-1', 'house-that-is-gone', 'uid-a');

    const report = await backfillMembershipIndex(db, { apply: true });

    assert.ok(
      report.anomalies.some((a) => a.kind === 'active-member-of-missing-house'),
    );
    assert.strictEqual(report.summary.anomalies, 1);
  });

  test('a clean dataset reports NO anomalies', async () => {
    // The negative control — otherwise "0 anomalies" proves nothing.
    await seedHouse('h1');
    await seedMember('m-1', 'h1', 'uid-a');
    await seedMember('m-2', 'h1', 'uid-gone', { isActive: false });

    const report = await backfillMembershipIndex(db, { apply: true });

    assert.deepStrictEqual(report.anomalies, []);
    assert.strictEqual(report.summary.anomalies, 0);
  });

  test('the exit signal is non-zero when anomalies exist', async () => {
    // main() returns 1 on anomalies; the summary is what it reads.
    await seedMember('m-1', 'house-that-is-gone', 'uid-a');
    const report = await backfillMembershipIndex(db);
    assert.ok(report.summary.anomalies > 0);
  });
});

describe('backfill — scale', () => {
  test('more entries than one batch still all get written', async () => {
    // BATCH_LIMIT exists because Firestore caps a batch at 500 writes.
    await seedHouse('h1');
    const total = BATCH_LIMIT + 25;
    for (let i = 0; i < total; i++) {
      await seedMember(`m-${i}`, 'h1', `uid-${i}`);
    }

    const report = await backfillMembershipIndex(db, { apply: true });

    assert.strictEqual(report.summary.written, total);
    assert.strictEqual((await allIndexPaths()).length, total);
  });
});
