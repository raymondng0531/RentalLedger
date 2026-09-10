/**
 * Self-test for the read-only balance reconciliation.
 *
 * Proves the tool actually DETECTS mismatches rather than silently reporting
 * success — a reconciliation that can only say "all good" is worse than none.
 *
 * Runs against the Firestore emulator. The TEST seeds data (via admin, which
 * bypasses rules); `reconcile_balance.js` itself only ever reads.
 *
 *   cd tool && npm install && npm test
 */
'use strict';

const assert = require('node:assert');
const { test, before, after, describe } = require('node:test');

const admin = require('firebase-admin');

const {
  reconcileBalances,
  STATUS_MATCH,
  STATUS_MISMATCH,
  STATUS_NO_HISTORY,
} = require('./reconcile_balance');

const PROJECT_ID = 'rental-ledger-reconcile';

let db;

/** Seeds a house plus its transactions. */
async function seedHouse(houseId, storedBalance, transactions, extraHouse = {}) {
  await db.collection('houses').doc(houseId).set({
    houseId,
    houseName: `House ${houseId}`,
    inviteCode: 'CODE01',
    treasurerId: 'uid-treasurer',
    balance: storedBalance,
    currency: 'MYR',
    ...extraHouse,
  });
  for (let i = 0; i < transactions.length; i++) {
    await db
      .collection('transactions')
      .doc(`${houseId}-tx-${i}`)
      .set({
        houseId,
        type: transactions[i].type ?? 'Deposit',
        amount: transactions[i].amount,
        performedBy: 'uid-treasurer',
      });
  }
}

/** Finds the row for one house, failing loudly if it is missing. */
function rowFor(report, houseId) {
  const row = report.rows.find((r) => r.houseId === houseId);
  assert.ok(row, `no report row for ${houseId}`);
  return row;
}

before(async () => {
  admin.initializeApp({ projectId: PROJECT_ID });
  db = admin.firestore();
});

after(async () => {
  await admin.app().delete();
});

describe('balance reconciliation — detection', () => {
  test('a house whose mirror matches its history reports match', async () => {
    // 1200 in, 350 out → 850.
    await seedHouse('h-match', 850, [
      { type: 'Deposit', amount: 1200 },
      { type: 'Direct Payment', amount: -350 },
    ]);

    const row = rowFor(await reconcileBalances(db), 'h-match');
    assert.strictEqual(row.status, STATUS_MATCH);
    assert.strictEqual(row.computedBalance, 850);
    assert.strictEqual(row.storedBalance, 850);
    assert.strictEqual(row.difference, 0);
    assert.strictEqual(row.transactionCount, 2);
  });

  test('a drifted mirror is reported as a mismatch with the exact difference', async () => {
    // The mirror says 1000 but history sums to 850 — the drift the repair exists for.
    await seedHouse('h-drift', 1000, [
      { type: 'Deposit', amount: 1200 },
      { type: 'Direct Payment', amount: -350 },
    ]);

    const report = await reconcileBalances(db);
    const row = rowFor(report, 'h-drift');
    assert.strictEqual(row.status, STATUS_MISMATCH);
    assert.strictEqual(row.storedBalance, 1000);
    assert.strictEqual(row.computedBalance, 850);
    assert.strictEqual(row.difference, 150);
    assert.ok(
      report.summary.mismatched >= 1,
      'the summary must count the mismatch',
    );
  });

  test('a negative drifted mirror is caught too', async () => {
    await seedHouse('h-under', -50, [{ type: 'Deposit', amount: 100 }]);

    const row = rowFor(await reconcileBalances(db), 'h-under');
    assert.strictEqual(row.status, STATUS_MISMATCH);
    assert.strictEqual(row.difference, -150);
  });

  test('reimbursement and deposit signs are summed as stored', async () => {
    // Deposit stores positive; Reimbursement stores negative. Sum = 200.
    await seedHouse('h-signs', 200, [
      { type: 'Deposit', amount: 500 },
      { type: 'Reimbursement', amount: -300 },
    ]);

    const row = rowFor(await reconcileBalances(db), 'h-signs');
    assert.strictEqual(row.status, STATUS_MATCH);
    assert.strictEqual(row.computedBalance, 200);
  });

  test('a house with no transaction history is unverifiable, not "wrong"', async () => {
    // The dashboard falls back to the stored value when there is no history,
    // so this must NOT be reported as a mismatch.
    await seedHouse('h-empty', 750, []);

    const row = rowFor(await reconcileBalances(db), 'h-empty');
    assert.strictEqual(row.status, STATUS_NO_HISTORY);
    assert.strictEqual(row.transactionCount, 0);
  });

  test('another house\'s transactions are never counted', async () => {
    await seedHouse('h-scope-a', 100, [{ type: 'Deposit', amount: 100 }]);
    await seedHouse('h-scope-b', 100, [{ type: 'Deposit', amount: 999 }]);

    const report = await reconcileBalances(db);
    assert.strictEqual(rowFor(report, 'h-scope-a').computedBalance, 100);
    assert.strictEqual(rowFor(report, 'h-scope-b').computedBalance, 999);
    assert.strictEqual(rowFor(report, 'h-scope-a').status, STATUS_MATCH);
    assert.strictEqual(rowFor(report, 'h-scope-b').status, STATUS_MISMATCH);
  });

  test('a missing amount is counted as 0 and flagged, not silently ignored', async () => {
    await seedHouse('h-malformed', 100, [{ type: 'Deposit', amount: 100 }]);
    // A transaction document with no usable amount — the Dart reader also
    // yields 0 here, so the sums still agree, but the defect is surfaced.
    await db.collection('transactions').doc('h-malformed-tx-bad').set({
      houseId: 'h-malformed',
      type: 'Deposit',
      performedBy: 'uid-treasurer',
    });

    const report = await reconcileBalances(db);
    const row = rowFor(report, 'h-malformed');
    assert.strictEqual(row.computedBalance, 100);
    assert.strictEqual(row.status, STATUS_MATCH);
    assert.strictEqual(row.malformedAmounts, 1);
    assert.ok(report.summary.malformedAmounts >= 1);
  });

  test('sub-cent noise below the tolerance is not reported as a mismatch', async () => {
    await seedHouse('h-epsilon', 100.001, [{ type: 'Deposit', amount: 100 }]);

    const row = rowFor(await reconcileBalances(db), 'h-epsilon');
    assert.strictEqual(row.status, STATUS_MATCH);
  });

  test('the report never contains anything but the listed fields', async () => {
    // Guards the "do not expose private data unnecessarily" requirement: the
    // report carries ids and money, never member identities or invite codes.
    await seedHouse('h-privacy', 0, [{ type: 'Deposit', amount: 0 }], {
      inviteCode: 'SECRET',
    });

    const report = await reconcileBalances(db);
    const row = rowFor(report, 'h-privacy');
    assert.deepStrictEqual(Object.keys(row).sort(), [
      'computedBalance',
      'difference',
      'houseId',
      'houseName',
      'malformedAmounts',
      'status',
      'storedBalance',
      'transactionCount',
    ]);
    assert.ok(!JSON.stringify(report).includes('SECRET'));
  });
});
