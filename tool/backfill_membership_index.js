#!/usr/bin/env node
/**
 * BACKFILL the membership authorization index for Rental Ledger.
 *
 * Creates `houses/{houseId}/members/{userId}` for every membership that already
 * exists in `house_members`, so the tightened Firestore rules (which read that
 * path) authorize today's members instead of locking everyone out.
 *
 * ── DRY RUN BY DEFAULT ──
 * Running this with no flag CHANGES NOTHING. It prints exactly what it would
 * write. Pass `--apply` to perform the writes.
 *
 *   node backfill_membership_index.js --project rental-ledger-app            # dry run
 *   node backfill_membership_index.js --project rental-ledger-app --apply    # write
 *
 * ── IDENTITY-PRESERVING ──
 * `house_members` documents are READ, never written, never deleted, never
 * re-keyed. The random document ids stay exactly as they are. The index is a
 * SEPARATE collection — this script only ever creates/merges documents under
 * `houses/{houseId}/members/`. Historical membership history is therefore
 * untouched by construction, not by discipline.
 *
 * ── IDEMPOTENT ──
 * The index is derived, not accumulated. Every run recomputes each entry from
 * the full set of that (house, user) pair's rows and merges the result, so
 * running it twice changes nothing the second time, and running it after the
 * Cloud Function has already written an entry leaves that entry consistent.
 *
 * ── SCOPE ──
 * This backfills CURRENT authorization state only. An (house, user) pair with
 * no active row gets `isActive: false`, which is the correct "not authorized"
 * answer; it is not a record that the person was ever a member. Historical
 * membership remains `house_members`' job.
 *
 * ── WHY THE AGGREGATION LOOKS LIKE THIS ──
 * A person can hold SEVERAL `house_members` rows for one house: Remove Member
 * and Leave House are both soft deletes, so the old row survives a rejoin. The
 * index entry is therefore computed by OR-ing every row for the pair —
 * mirroring `syncMemberIndex` in functions/index.js exactly. Copying whichever
 * row happened to be read last would let a stale soft-deleted row deactivate a
 * currently-active member.
 *
 * ── USAGE ──
 * Emulator (no credentials):
 *   node backfill_membership_index.js --emulator --project rental-ledger-backfill --apply
 * Production: see tool/README.md for credentials, then run a DRY RUN first.
 *
 * Flags:
 *   --project <id>   Firebase project id (default: rental-ledger-app)
 *   --emulator       Target the local Firestore emulator instead of production
 *   --apply          Actually write. Without it this is a dry run.
 *   --json           Emit the report as JSON instead of a table
 *
 * Exit codes: 0 = ok, 1 = anomalies found, 2 = error.
 */
'use strict';

// The derivation rule is SHARED with the live Cloud Function trigger
// (functions/index.js), not reimplemented here. If the two disagreed, a
// member's authorization would depend on which writer ran last.
const { summarizeMembership } = require('../functions/membership_index');

const DEFAULT_PROJECT = 'rental-ledger-app';

/** Firestore caps a batched write at 500 operations; stay well under. */
const BATCH_LIMIT = 400;

/**
 * Recomputes the authorization index entries from `house_members`.
 *
 * @param {FirebaseFirestore.Firestore} db an admin Firestore handle
 * @param {{apply?: boolean}} [options] `apply:false` (default) reads only.
 * @returns {Promise<{entries: Array<object>, anomalies: Array<object>, summary: object}>}
 */
async function backfillMembershipIndex(db, { apply = false } = {}) {
  const membersSnap = await db.collection('house_members').get();

  // Which houses actually exist? An index entry under a missing house would be
  // unreachable and signals corrupt membership data.
  const housesSnap = await db.collection('houses').get();
  const houseIds = new Set(housesSnap.docs.map((d) => d.id));

  /** key = `${houseId} ${userId}` */
  const pairs = new Map();
  const anomalies = [];
  let rowsWithoutKeys = 0;
  let rowsWithImplicitActive = 0;

  for (const doc of membersSnap.docs) {
    const data = doc.data() || {};
    const houseId = typeof data.houseId === 'string' ? data.houseId : '';
    const userId = typeof data.userId === 'string' ? data.userId : '';

    if (!houseId || !userId) {
      // The Cloud Function also skips these. They cannot produce a path.
      rowsWithoutKeys++;
      anomalies.push({
        kind: 'row-missing-keys',
        memberId: doc.id,
        houseId: houseId || null,
        userId: userId || null,
      });
      continue;
    }

    // `isActive` is absent on the oldest records; the app's model defaults it
    // to true, so mirror that rather than treating missing as false.
    if (data.isActive === undefined) rowsWithImplicitActive++;

    const key = `${houseId} ${userId}`;
    let entry = pairs.get(key);
    if (!entry) {
      entry = { houseId, userId, rows: [], rowData: [] };
      pairs.set(key, entry);
    }
    entry.rows.push(doc.id);
    entry.rowData.push(data);
  }

  const entries = [];
  for (const pair of pairs.values()) {
    // The SAME derivation rule the live Cloud Function trigger applies — see
    // functions/membership_index.js. Not reimplemented here, so the two writers
    // cannot drift.
    const { isActive, role, activeRows } = summarizeMembership(pair.rowData);

    if (activeRows > 1) {
      // Two simultaneously-active rows for one person in one house. The app
      // never creates this, so it means a partial failure somewhere. Reported,
      // not "fixed" — deduplicating membership rows is not this tool's call.
      anomalies.push({
        kind: 'multiple-active-rows',
        houseId: pair.houseId,
        userId: pair.userId,
        activeRows,
        memberIds: pair.rows,
      });
    }
    if (isActive && !houseIds.has(pair.houseId)) {
      anomalies.push({
        kind: 'active-member-of-missing-house',
        houseId: pair.houseId,
        userId: pair.userId,
      });
    }

    entries.push({
      houseId: pair.houseId,
      userId: pair.userId,
      isActive,
      role,
      sourceRows: pair.rows.length,
    });
  }

  // Deterministic order so a dry run and its follow-up apply line up.
  entries.sort((a, b) =>
    a.houseId === b.houseId
      ? a.userId.localeCompare(b.userId)
      : a.houseId.localeCompare(b.houseId),
  );
  anomalies.sort((a, b) => a.kind.localeCompare(b.kind));

  let written = 0;
  if (apply && entries.length > 0) {
    for (let i = 0; i < entries.length; i += BATCH_LIMIT) {
      const batch = db.batch();
      for (const entry of entries.slice(i, i + BATCH_LIMIT)) {
        batch.set(
          db.doc(`houses/${entry.houseId}/members/${entry.userId}`),
          {
            userId: entry.userId,
            houseId: entry.houseId,
            isActive: entry.isActive,
            role: entry.role,
            sourceRows: entry.sourceRows,
            updatedAt: new Date(),
          },
          { merge: true },
        );
      }
      await batch.commit();
      written += Math.min(BATCH_LIMIT, entries.length - i);
    }
  }

  return {
    entries,
    anomalies,
    summary: {
      applied: apply,
      memberRows: membersSnap.docs.length,
      membershipPairs: entries.length,
      activeEntries: entries.filter((e) => e.isActive).length,
      inactiveEntries: entries.filter((e) => !e.isActive).length,
      treasurerEntries: entries.filter((e) => e.role === 'Treasurer').length,
      rowsWithoutKeys,
      rowsWithImplicitActive,
      written,
      anomalies: anomalies.length,
    },
  };
}

function renderTable(report, { limit = 40 } = {}) {
  const { entries, anomalies, summary } = report;
  const lines = [];
  lines.push('');
  lines.push(
    summary.applied
      ? '  BACKFILL — MEMBERSHIP AUTHORIZATION INDEX (writes performed)'
      : '  DRY RUN — MEMBERSHIP AUTHORIZATION INDEX (nothing written)',
  );
  lines.push('');
  lines.push(`  house_members rows read : ${summary.memberRows}`);
  lines.push(`  membership pairs found  : ${summary.membershipPairs}`);
  lines.push(`    active (isActive:true) : ${summary.activeEntries}`);
  lines.push(`    inactive               : ${summary.inactiveEntries}`);
  lines.push(`    role Treasurer         : ${summary.treasurerEntries}`);
  lines.push(
    `  index documents written : ${summary.written}` +
      (summary.applied ? '' : '   (dry run — pass --apply to write)'),
  );
  lines.push('');

  if (summary.rowsWithImplicitActive > 0) {
    lines.push(
      `  NOTE: ${summary.rowsWithImplicitActive} row(s) have no isActive field. ` +
        'The app\ntreats those as active, and so does this backfill.',
    );
    lines.push('');
  }

  const shown = entries.slice(0, limit);
  if (shown.length > 0) {
    const table = [
      ['HOUSE ID', 'USER ID', 'ACTIVE', 'ROLE', 'ROWS'],
      ...shown.map((e) => [
        e.houseId,
        e.userId,
        e.isActive ? 'yes' : 'no',
        e.role,
        String(e.sourceRows),
      ]),
    ];
    lines.push(...renderColumns(table));
    if (entries.length > shown.length) {
      lines.push(`  … and ${entries.length - shown.length} more.`);
    }
    lines.push('');
  }

  if (anomalies.length > 0) {
    lines.push(`  ANOMALIES (${anomalies.length}) — reported, not repaired:`);
    for (const a of anomalies.slice(0, limit)) {
      lines.push(`    [${a.kind}] ${JSON.stringify(a)}`);
    }
    if (anomalies.length > limit) {
      lines.push(`    … and ${anomalies.length - limit} more.`);
    }
    lines.push('');
  }

  lines.push(
    '  Nothing was deleted, rewritten or re-keyed: house_members is read-only\n' +
      '  here, and the index is a separate collection.',
  );
  lines.push('');
  return lines.join('\n');
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
    apply: false,
    json: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project') opts.project = argv[++i];
    else if (a === '--emulator') opts.emulator = true;
    else if (a === '--apply') opts.apply = true;
    else if (a === '--json') opts.json = true;
    else if (a === '--help' || a === '-h') opts.help = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  return opts;
}

const USAGE = `Usage: node backfill_membership_index.js [--project <id>] [--emulator] [--apply] [--json]

Derives houses/{houseId}/members/{userId} from house_members.
Never writes or deletes house_members. Dry run unless --apply is passed.`;

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
    report = await backfillMembershipIndex(admin.firestore(), {
      apply: opts.apply,
    });
  } catch (e) {
    console.error(`\nBackfill failed: ${e.message}\n`);
    return 2;
  }

  if (opts.json) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    console.log(renderTable(report));
    if (!opts.apply) {
      console.log(
        '  Re-run with --apply to write these entries. Review the counts and\n' +
          '  any anomalies above first.\n',
      );
    }
  }

  return report.summary.anomalies > 0 ? 1 : 0;
}

module.exports = {
  backfillMembershipIndex,
  renderTable,
  BATCH_LIMIT,
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
