/**
 * Tests for the membership-index derivation rule.
 *
 * This is the one piece of logic that decides whether a person is AUTHORIZED
 * in a house, and it is applied by two different writers (the live Cloud
 * Function trigger and the backfill tool). A defect here does not throw — it
 * silently deauthorizes an active member, or silently leaves a removed member
 * authorized. Both are the kind of bug that surfaces months later as "why can't
 * I see my own house?" or "why can he still see everything?".
 *
 * Run:
 *   cd functions && npm test
 */
const assert = require('node:assert');
const { test, describe } = require('node:test');

const {
  summarizeMembership,
  ROLE_TREASURER,
  ROLE_MEMBER,
} = require('./membership_index');

describe('summarizeMembership — the authorization decision', () => {
  test('no rows at all means NOT authorized', () => {
    // Somebody who belongs to no house. This is the answer the rules turn into
    // a denial, so a wrong `true` here would open every house-scoped read.
    const s = summarizeMembership([]);
    assert.strictEqual(s.isActive, false);
    assert.strictEqual(s.activeRows, 0);
    assert.strictEqual(s.totalRows, 0);
  });

  test('a missing argument is treated as no rows, not a crash', () => {
    assert.strictEqual(summarizeMembership(undefined).isActive, false);
    assert.strictEqual(summarizeMembership(null).isActive, false);
  });

  test('one active Member row authorizes a Member', () => {
    const s = summarizeMembership([{ role: ROLE_MEMBER, isActive: true }]);
    assert.strictEqual(s.isActive, true);
    assert.strictEqual(s.role, ROLE_MEMBER);
    assert.strictEqual(s.activeRows, 1);
  });

  test('one active Treasurer row authorizes a Treasurer', () => {
    const s = summarizeMembership([{ role: ROLE_TREASURER, isActive: true }]);
    assert.strictEqual(s.isActive, true);
    assert.strictEqual(s.role, ROLE_TREASURER);
  });

  test('an explicitly inactive row does NOT authorize', () => {
    // Remove Member and Leave House both write this. If it authorized, removal
    // would not remove anything.
    const s = summarizeMembership([{ role: ROLE_MEMBER, isActive: false }]);
    assert.strictEqual(s.isActive, false);
    assert.strictEqual(s.activeRows, 0);
    assert.strictEqual(s.totalRows, 1);
  });

  test('a MISSING isActive is treated as ACTIVE (legacy records)', () => {
    // The oldest house_members rows have no isActive field, and the app's model
    // defaults it to true. Reading a missing field as inactive would lock every
    // legacy member out of their own house on the day the rules land.
    const s = summarizeMembership([{ role: ROLE_MEMBER }]);
    assert.strictEqual(s.isActive, true);
    assert.strictEqual(s.activeRows, 1);
  });

  test('a REMOVED-then-REJOINED member is authorized by their newer row', () => {
    // THE case this whole derivation exists for. Two rows for one person: the
    // superseded soft-deleted one, and the current active one. Copying
    // whichever row was written last is not good enough — the answer must come
    // from the SET.
    const s = summarizeMembership([
      { role: ROLE_MEMBER, isActive: false },
      { role: ROLE_MEMBER, isActive: true },
    ]);
    assert.strictEqual(s.isActive, true);
    assert.strictEqual(s.activeRows, 1);
    assert.strictEqual(s.totalRows, 2);
  });

  test('row ORDER does not change the answer', () => {
    // Order-independence is what makes the derivation idempotent and
    // self-healing: whichever row fired the trigger, the recomputation sees the
    // same set and writes the same entry.
    const rows = [
      { role: ROLE_MEMBER, isActive: false },
      { role: ROLE_MEMBER, isActive: true },
      { role: ROLE_MEMBER, isActive: false },
    ];
    const forward = summarizeMembership(rows);
    const backward = summarizeMembership([...rows].reverse());
    assert.deepStrictEqual(forward, backward);
    assert.strictEqual(forward.isActive, true);
  });

  test('a SUPERSEDED Treasurer row does NOT keep the role alive', () => {
    // Transfer Treasurer rewrites role on two rows. If a stale soft-deleted
    // Treasurer row still conferred the role, the OLD treasurer would keep
    // Treasurer UI — and the money operations it gates — after handing over.
    const s = summarizeMembership([
      { role: ROLE_TREASURER, isActive: false },
      { role: ROLE_MEMBER, isActive: true },
    ]);
    assert.strictEqual(s.isActive, true);
    assert.strictEqual(s.role, ROLE_MEMBER);
  });

  test('an ACTIVE Treasurer row wins over other active Members', () => {
    const s = summarizeMembership([
      { role: ROLE_MEMBER, isActive: true },
      { role: ROLE_TREASURER, isActive: true },
    ]);
    assert.strictEqual(s.role, ROLE_TREASURER);
  });

  test('all rows inactive means NOT authorized, whatever the role', () => {
    // A treasurer who left the house must not remain authorized.
    const s = summarizeMembership([
      { role: ROLE_TREASURER, isActive: false },
      { role: ROLE_MEMBER, isActive: false },
    ]);
    assert.strictEqual(s.isActive, false);
    assert.strictEqual(s.activeRows, 0);
  });

  test('a malformed null row is skipped rather than throwing', () => {
    const s = summarizeMembership([null, { role: ROLE_MEMBER, isActive: true }]);
    assert.strictEqual(s.isActive, true);
    // The null still counts toward totalRows, which is only a diagnostic.
    assert.strictEqual(s.totalRows, 2);
  });

  test('an unknown role falls back to Member, never Treasurer', () => {
    // Fail CLOSED on the privileged role: a typo or an unexpected value must
    // not hand out Treasurer.
    const s = summarizeMembership([{ role: 'treasurer', isActive: true }]);
    assert.strictEqual(s.isActive, true);
    assert.strictEqual(s.role, ROLE_MEMBER);
  });
});

describe('summarizeMembership — the shape the index document gets', () => {
  test('every field the index writer persists is present', () => {
    const s = summarizeMembership([{ role: ROLE_MEMBER, isActive: true }]);
    // syncMemberIndex and the backfill both write isActive/role/sourceRows.
    // `activeRows` is diagnostic only.
    assert.deepStrictEqual(Object.keys(s).sort(), [
      'activeRows',
      'isActive',
      'role',
      'totalRows',
    ]);
    assert.strictEqual(typeof s.isActive, 'boolean');
    assert.strictEqual(typeof s.role, 'string');
    assert.strictEqual(typeof s.totalRows, 'number');
  });

  test('isActive is ALWAYS a boolean — never undefined', () => {
    // The rules compare `.isActive == true`. A non-boolean would make the rule
    // error, and an erroring rule DENIES — so this must never be undefined.
    for (const rows of [[], [{}], [{ isActive: false }], [{ isActive: true }]]) {
      assert.strictEqual(typeof summarizeMembership(rows).isActive, 'boolean');
    }
  });

  test('role is ALWAYS one of the two known strings', () => {
    // The rules expose role to the UI. A third value would silently misreport
    // the member list.
    for (const rows of [[], [{}], [{ role: 'x' }], [{ role: ROLE_TREASURER }]]) {
      const { role } = summarizeMembership(rows);
      assert.ok(
        role === ROLE_TREASURER || role === ROLE_MEMBER,
        `unexpected role: ${role}`,
      );
    }
  });
});
