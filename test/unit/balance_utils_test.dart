import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/balance_utils.dart';

/// Pins the DEFINITION of the Central Account Balance.
///
/// `computeCentralBalance` is the documented financial source of truth: the
/// Dashboard, the Reports page, the reimbursement/direct-payment balance
/// preconditions, and the balance-mirror repair all reduce to this one
/// function. Until this file existed, nothing asserted what it actually
/// computes — a change here would have silently moved every balance in the
/// app, and silently invalidated `tool/reconcile_balance.js`, which mirrors
/// this formula to check `houses.balance` against transaction history.
///
/// If a change to the formula is ever intended, it must be made in BOTH
/// places and these expectations updated deliberately. If these tests fail,
/// the reconciliation tool is lying.
void main() {
  group('computeCentralBalance — the balance contract', () {
    test('an empty house has a zero balance', () {
      expect(computeCentralBalance(const []), 0);
    });

    test('deposits (stored positive) add', () {
      expect(computeCentralBalance(const [1200]), 1200);
    });

    test('outflows (stored negative) subtract', () {
      // Direct Payments and Reimbursements are written with a negative signed
      // amount, so the plain sum already subtracts them. The function does not
      // look at `type` at all.
      expect(computeCentralBalance(const [1200, -350]), 850);
    });

    test('the function ignores transaction type entirely', () {
      // Sign is the only input that matters: a hypothetical mis-signed row
      // moves the balance by its numeric value regardless of its label.
      // Asserted so nobody "fixes" the sum by adding a type filter without
      // changing the writers too.
      expect(computeCentralBalance(const [100]), 100);
      expect(computeCentralBalance(const [-100]), -100);
    });

    test('adjustments use their signed amount as-is', () {
      expect(computeCentralBalance(const [500, 250, -100]), 650);
    });

    test('a balance can legitimately go negative (refund owed)', () {
      // The app PREVENTS new outflows from overdrawing at the transaction
      // level, but historical data can still sum negative. The formula must
      // report that faithfully rather than clamping to zero.
      expect(computeCentralBalance(const [100, -250]), -150);
    });

    test('the sum is order-independent', () {
      final a = computeCentralBalance(const [1200, -350, 75, -25]);
      final b = computeCentralBalance(const [-25, 75, -350, 1200]);
      expect(a, b);
      expect(a, 900);
    });

    test('fractional amounts accumulate without special casing', () {
      expect(computeCentralBalance(const [42.5, -0.25, 0.75]), closeTo(43, 1e-9));
    });

    test('a real month reconciles to the expected closing balance', () {
      // Rent in, a bill and a reimbursement out — the shape the Dashboard
      // shows as "Central Account Balance".
      expect(
        computeCentralBalance(const [3000, -1200, -350, -42.5]),
        1407.5,
      );
    });
  });
}
