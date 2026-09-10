# `tool/` — operational tools

Admin tools that need credentials the app itself never has. Nothing here is
part of the Flutter app or the deployed Cloud Functions.

`reconcile_balance.js` is READ-ONLY. `backfill_membership_index.js` writes, but
only to a collection the app never writes, and only when you pass `--apply`.

## `reconcile_balance.js` — balance reconciliation

Answers one question, for every house:

> Does `houses.balance` equal the sum of that house's transaction amounts?

Transaction history is the documented financial source of truth
(`computeCentralBalance` in `lib/core/utils/balance_utils.dart`).
`houses.balance` is a materialised mirror, kept in step by the same Firestore
transaction that writes each money movement, plus a compare-and-set repair on
the Treasurer's dashboard load. This tool checks whether that actually holds
for the data in production.

### It never writes

The script only calls `get()` on queries and documents. It contains no `set`,
`update`, `delete`, `batch` or `transaction` call. **Mismatches are reported,
never repaired** — deciding what to do about a drifted house is a human
decision, and automatic repair of financial data is exactly what this tool
exists to avoid.

### Running it against production

Admin credentials are required (security rules stop a normal client from
listing all houses). Nothing in this repo contains them — there is no service
account key and no `.env` checked in, deliberately.

Pick ONE of:

**a) Application Default Credentials (preferred — no long-lived key)**

```bash
gcloud auth application-default login
cd tool && npm install
node reconcile_balance.js --project rental-ledger-app
```

Note: `gcloud` is currently broken on this machine (`gcloud failed to load …
running gcloud with Python 3.9, which is no longer supported`). Fix it by
installing Python 3.10+ and setting `CLOUDSDK_PYTHON`, or use (b).

**b) A service-account key (a long-lived credential — treat it accordingly)**

Firebase Console → Project Settings → Service accounts → *Generate new private
key*, then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
cd tool && npm install
node reconcile_balance.js --project rental-ledger-app
```

Store the key outside the repo, and **delete it in the Console when you are
done**. It grants full read/write to the project and is not covered by rules.

### Running it against the emulator (no credentials)

```bash
cd tool && npm install && npm test      # self-test: 9 assertions on an emulator
node reconcile_balance.js --emulator --project rental-ledger-reconcile
```

`npm test` seeds the emulator with a deliberately drifted house and asserts the
tool reports it — a reconciliation that can only ever say "all good" is worse
than none.

### Flags

| Flag | Meaning |
|---|---|
| `--project <id>` | Firebase project id (default `rental-ledger-app`) |
| `--emulator` | Target the local Firestore emulator instead of production |
| `--names` | Also print house names. Off by default — the id is enough to act on, and the report is kept to ids and money. |
| `--json` | Machine-readable report |
| `--epsilon <n>` | Match tolerance (default `0.005`, matching the app's repair threshold) |

Exit codes: `0` all match · `1` at least one mismatch · `2` error.

### Reading the output

```
HOUSE ID      STORED    COMPUTED  DIFF     TXNS  STATUS
------------  --------  --------  -------  ----  ----------------
house-new     0.00      0.00      0.00     0     no history
house-ridge   +1500.00  +1200.00  +300.00  3     MISMATCH +300.00
house-sunset  +850.00   +850.00   0.00     2     match
```

- **`match`** — the mirror agrees with history within tolerance.
- **`MISMATCH`** — they disagree. The `DIFF` is `stored − computed`: positive
  means the mirror is overstated (it claims more money than the history
  supports). Investigate before changing anything.
- **`no history`** — the house has zero transactions. This is **not** a
  mismatch: the app deliberately falls back to the stored value when there is
  no history to sum, so the figure is unverifiable rather than wrong.

A `WARNING` line reports transactions with a missing or non-numeric `amount`.
The Dart reader treats those as `0` too (so the sums still agree), but the
defect is surfaced rather than absorbed.

### Keeping it honest

`reconcile_balance.js` reimplements the one-line sum from
`computeCentralBalance` because it runs outside Dart. If that formula ever
changes, this tool must change with it.
`test/unit/balance_utils_test.dart` pins the Dart side; these two must agree.

## `backfill_membership_index.js` — membership index backfill

Answers a different question:

> For every `(houseId, userId)` pair in `house_members`, who should be
> authorized in that house?

`firestore.rules` authorizes a house-scoped read with a **`get()` on
`houses/{houseId}/members/{uid}`** — a predictable path built from the
requesting uid. Rules can `get()` a document but can never query a collection,
which is exactly why the membership *index* exists: `house_members` is keyed by
random id and cannot be looked up from a rule, so the answer is materialised
where it can be.

**This tool is what authorizes every existing member on the day the tightened
rules land.** Run it BEFORE deploying `firestore.rules`, or every current member
is locked out of their own house.

### It writes only the index

It reads `house_members` and writes `houses/{houseId}/members/{userId}`. It
**never** writes, deletes or re-keys `house_members` — random document ids and
historical (departed-member) rows survive untouched. That is asserted directly
by `npm test`, not just intended.

The derivation is `summarizeMembership` from `functions/membership_index.js` —
the *same* module the live Cloud Function trigger uses, imported rather than
re-implemented so the two writers cannot drift. If they disagreed, a member
could be authorized by one and deauthorized by the other depending on which ran
last.

### It is idempotent and self-healing

Running it twice writes the same entries. Running it after the Cloud Function
has already written an entry agrees with that entry, and *repairs* one that has
drifted from the row set. The answer is derived from the whole set of rows for a
pair, so it does not depend on ordering or on which row fired last.

### Dry run first — always

`node backfill_membership_index.js` (no flag) writes **nothing** and prints the
full report. Read it. Then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
cd tool && npm install
node backfill_membership_index.js --project rental-ledger-app            # dry run
node backfill_membership_index.js --project rental-ledger-app --apply    # write
```

| Flag | Meaning |
|---|---|
| `--project <id>` | Firebase project id (default `rental-ledger-app`) |
| `--emulator` | Target the local Firestore emulator instead of production |
| `--apply` | Actually write. Without it this is a dry run. |
| `--json` | Machine-readable report |

Exit codes: `0` clean · `1` anomalies reported · `2` error.

### Reading the output

`written` is index entries written. `membershipPairs` is the number of distinct
`(house, user)` pairs found — compare the two: equal means every pair got an
entry. `activeEntries` vs `inactiveEntries` should match your expectation of who
currently lives in each house; a surprise there is the thing to stop for.

**Anomalies are reported, never repaired:**

| Kind | Means |
|---|---|
| `row-missing-keys` | A `house_members` row with no `houseId`/`userId`. Skipped — it cannot be attributed to a house. |
| `multiple-active-rows` | Two simultaneously-active rows for one person. The app never creates this, so it means a partial failure somewhere. Reported with both `memberIds`; **not** deduplicated, because deleting a membership row is not this tool's decision. |
| `active-member-of-missing-house` | An active member whose house document does not exist. The index entry would be written under a house that is not there. |
| `unexpected-role` | A row whose `role` is present but is neither `Treasurer` nor `Member` — a typo, a casing difference (`treasurer`), a stray space, or a value from some other writer. Such rows **derive as `Member`, never `Treasurer`** (the derivation fails closed and is deliberately unchanged), so the failure is safe but silent: the index records `Member` where the historical row says something else. Reported so you can look. A row with **no** `role` field is *not* reported — the app's own model defaults it to `Member`, so it is a legitimate legacy shape, exactly like a missing `isActive`. |

A non-zero exit is a signal to look, not a failure — the run still completes and
still writes the pairs it could attribute.

### Keeping it honest

`npm test` runs 32 assertions against the emulator covering the derivation, the
dry-run/apply agreement, identity preservation, idempotence, anomaly reporting
(including `unexpected-role`, and that a bad role still derives as `Member`) and
a dataset larger than one write batch (Firestore caps a batch at 500). The
identity-preservation and idempotence tests exist because those are the two ways
this tool could do real damage.

