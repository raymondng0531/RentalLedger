#!/usr/bin/env node
/**
 * READ-ONLY balance reconciliation for Rental Ledger.
 *
 * Verifies that `houses.balance` (the materialised mirror) equals the
 * authoritative figure: the sum of the signed `amount` of every document in
 * `transactions` for that house.
 *
 * ── SOURCE OF TRUTH ──
 * The authoritative definition is `computeCentralBalance` in
 * lib/core/utils/balance_utils.dart, which is a plain fold:
 *
 *     double computeCentralBalance(Iterable<double> amounts) =>
 *         amounts.fold(0, (sum, amount) => sum + amount);
 *
 * This tool deliberately reimplements that one-line sum rather than inventing
 * a second formula. If that function ever changes (e.g. to filter by
 * transaction type), THIS TOOL MUST CHANGE WITH IT — otherwise the two
 * silently disagree. `test/unit/balance_utils_test.dart` pins the Dart side;
 * keep them in step.
 *
 * ── THIS SCRIPT NEVER WRITES ──
 * It only ever calls `get()` on queries and documents. There is no `set`,
 * `update`, `delete`, `batch` or `transaction` call anywhere in this file.
 * Mismatches are REPORTED, never repaired — the dashboard's compare-and-set
 * repair (dashboard_remote_datasource.dart) performs the only automatic fix,
 * on the Treasurer's next load.
 *
 * ── USAGE ──
 * Production (needs admin credentials — see tool/README.md):
 *   node reconcile_balance.js --project rental-ledger-app
 *
 * Against the local emulator (no credentials needed):
 *   node reconcile_balance.js --emulator --project rental-ledger-reconcile
 *
 * Flags:
 *   --project <id>   Firebase project id (default: rental-ledger-app)
 *   --emulator       Target the local Firestore emulator instead of production
 *   --names          Also print the house name (off by default; the id is
 *                    enough to act on and names are not needed to reconcile)
 *   --json           Emit the report as JSON instead of a table
 *   --epsilon <n>    Match tolerance (default 0.005, matching the app's repair)
 *
 * Exit codes: 0 = every house matches, 1 = at least one mismatch, 2 = error.
 */
'use strict';

const DEFAULT_PROJECT = 'rental-ledger-app';

/** Match tolerance. Mirrors the app's own repair threshold. */
const EPSILON = 0.005;

const STATUS_MATCH = 'match';
const STATUS_MISMATCH = 'mismatch';
const STATUS_NO_HISTORY = 'no_history';

/**
 * Reads every house and compares its stored `balance` against the sum of its
 * transaction amounts.
 *
 * READ-ONLY. See the file header.
 *
 * @param {FirebaseFirestore.Firestore} db an admin Firestore handle
 * @param {{epsilon?: number}} [options]
 * @returns {Promise<{rows: Array<object>, summary: object}>}
 */
async function reconcileBalances(db, { epsilon = EPSILON } = {}) {
  const housesSnap = await db.collection('houses').get();

  const rows = [];
  for (const houseDoc of housesSnap.docs) {
    const house = houseDoc.data() || {};
    const storedBalance = typeof house.balance === 'number' ? house.balance : 0;

    // Every transaction for this house — no type/date/status filter, exactly
    // as the Dart callers query it.
    const txSnap = await db
      .collection('transactions')
      .where('houseId', '==', houseDoc.id)
      .get();

    let computedBalance = 0;
    let malformedAmounts = 0;
    for (const txDoc of txSnap.docs) {
      const raw = (txDoc.data() || {}).amount;
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        computedBalance += raw;
      } else {
        // A missing or non-numeric amount contributes 0 in the Dart code too
        // (`(t.data()['amount'] as num?)?.toDouble() ?? 0`), but it is a data
        // defect worth surfacing rather than silently absorbing.
        malformedAmounts += 1;
      }
    }

    const difference = storedBalance - computedBalance;
    const transactionCount = txSnap.size;

    // A house with no transaction history cannot be verified by summation:
    // the dashboard deliberately falls back to the stored value in that case
    // (see _fetchHouse), so this is "unverifiable", not "wrong".
    let status;
    if (transactionCount === 0) {
      status = STATUS_NO_HISTORY;
    } else if (Math.abs(difference) < epsilon) {
      status = STATUS_MATCH;
    } else {
      status = STATUS_MISMATCH;
    }

    rows.push({
      houseId: houseDoc.id,
      houseName: typeof house.houseName === 'string' ? house.houseName : null,
      storedBalance: round2(storedBalance),
      computedBalance: round2(computedBalance),
      difference: round2(difference),
      transactionCount,
      malformedAmounts,
      status,
    });
  }

  rows.sort((a, b) => a.houseId.localeCompare(b.houseId));

  const summary = {
    houses: rows.length,
    matched: rows.filter((r) => r.status === STATUS_MATCH).length,
    mismatched: rows.filter((r) => r.status === STATUS_MISMATCH).length,
    noHistory: rows.filter((r) => r.status === STATUS_NO_HISTORY).length,
    malformedAmounts: rows.reduce((n, r) => n + r.malformedAmounts, 0),
    totalAbsDifference: round2(
      rows
        .filter((r) => r.status === STATUS_MISMATCH)
        .reduce((n, r) => n + Math.abs(r.difference), 0),
    ),
  };

  return { rows, summary };
}

function round2(n) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Formats the report for a terminal. Never prints anything but these fields. */
function renderTable({ rows, summary }, { names = false } = {}) {
  const lines = [];
  lines.push('');
  lines.push('Rental Ledger — balance reconciliation (READ-ONLY, nothing written)');
  lines.push('');
  if (rows.length === 0) {
    lines.push('  No houses found.');
  } else {
    const header = names
      ? ['HOUSE ID', 'NAME', 'STORED', 'COMPUTED', 'DIFF', 'TXNS', 'STATUS']
      : ['HOUSE ID', 'STORED', 'COMPUTED', 'DIFF', 'TXNS', 'STATUS'];
    const body = rows.map((r) => {
      const cells = [
        r.houseId,
        ...(names ? [r.houseName ?? '-'] : []),
        fmt(r.storedBalance),
        fmt(r.computedBalance),
        fmt(r.difference),
        String(r.transactionCount),
        label(r),
      ];
      return cells;
    });
    lines.push(...renderColumns([header, ...body]));
  }
  lines.push('');
  lines.push(
    `  ${summary.houses} house(s): ${summary.matched} match, ` +
      `${summary.mismatched} MISMATCH, ${summary.noHistory} with no history`,
  );
  if (summary.malformedAmounts > 0) {
    lines.push(
      `  WARNING: ${summary.malformedAmounts} transaction(s) have a missing or ` +
        'non-numeric amount and were counted as 0.',
    );
  }
  lines.push('');
  return lines.join('\n');
}

function label(row) {
  if (row.status === STATUS_MATCH) return 'match';
  if (row.status === STATUS_MISMATCH) return `MISMATCH ${fmt(row.difference)}`;
  return 'no history';
}

function fmt(n) {
  const s = n.toFixed(2);
  return n > 0 ? `+${s}` : s;
}

function renderColumns(table) {
  const widths = table[0].map((_, i) =>
    Math.max(...table.map((r) => String(r[i]).length)),
  );
  return table.map((row, rowIndex) => {
    const line = row
      .map((cell, i) => String(cell).padEnd(widths[i]))
      .join('  ')
      .trimEnd();
    const rule =
      rowIndex === 0
        ? [widths.map((w) => '-'.repeat(w)).join('  ').trimEnd()]
        : [];
    return [line, ...rule].join('\n');
  });
}

function parseArgs(argv) {
  const opts = {
    project: DEFAULT_PROJECT,
    emulator: false,
    names: false,
    json: false,
    epsilon: EPSILON,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project') opts.project = argv[++i];
    else if (a === '--emulator') opts.emulator = true;
    else if (a === '--names') opts.names = true;
    else if (a === '--json') opts.json = true;
    else if (a === '--epsilon') opts.epsilon = Number(argv[++i]);
    else if (a === '--help' || a === '-h') opts.help = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  return opts;
}

const USAGE = `Usage: node reconcile_balance.js [--project <id>] [--emulator] [--names] [--json] [--epsilon <n>]

Read-only: reports houses.balance vs the sum of transaction amounts. Never writes.`;

async function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (e) {
    console.error(e.message);
    console.error(USAGE);
    return 2;
  }
  if (opts.help) {
    console.log(USAGE);
    return 0;
  }

  const admin = require('firebase-admin');

  if (opts.emulator && !process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  }

  try {
    if (opts.emulator) {
      admin.initializeApp({ projectId: opts.project });
    } else {
      admin.initializeApp({
        projectId: opts.project,
        credential: admin.credential.applicationDefault(),
      });
    }
  } catch (e) {
    console.error(
      `\nCould not initialise admin credentials for "${opts.project}".\n` +
        'See tool/README.md. Underlying error: ' +
        e.message +
        '\n',
    );
    return 2;
  }

  let report;
  try {
    report = await reconcileBalances(admin.firestore(), {
      epsilon: opts.epsilon,
    });
  } catch (e) {
    console.error(`\nReconciliation failed: ${e.message}\n`);
    return 2;
  }

  if (opts.json) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    console.log(renderTable(report, { names: opts.names }));
    if (report.summary.mismatched > 0) {
      console.log(
        '  Mismatches are reported only — nothing was repaired. Decide what to\n' +
          '  do per house before changing any production value.\n',
      );
    }
  }

  return report.summary.mismatched > 0 ? 1 : 0;
}

module.exports = {
  reconcileBalances,
  renderTable,
  EPSILON,
  STATUS_MATCH,
  STATUS_MISMATCH,
  STATUS_NO_HISTORY,
};

if (require.main === module) {
  main().then(
    (code) => process.exit(code),
    (e) => {
      console.error(e);
      process.exit(2);
    },
  );
}
