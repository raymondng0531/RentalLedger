# `tool/` — read-only operational tools

Admin tools that need credentials the app itself never has. Nothing here is
part of the Flutter app or the deployed Cloud Functions.

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
