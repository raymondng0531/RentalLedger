import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/ledger_submission_key.dart';
import 'package:rental_ledger/features/expenses/domain/logic/financial_guards.dart';

/// Phase 3 — financial workflow integrity.
///
/// These exercise the exact guards the Firestore data source evaluates INSIDE
/// its transactions: the source calls `expenseTransitionRefusal`,
/// `insufficientBalanceRefusal` and `duplicateBillPaymentRefusal` directly, so
/// what is asserted here is the production decision, not a reimplementation.
///
/// What these tests cannot prove is atomicity itself — that Firestore really
/// does serialise two racing writers so the loser re-reads and hits one of
/// these guards. That requires the Emulator (or two live clients) and is called
/// out in the Phase 3 report.
void main() {
  // ─────────────────────────────────────────────────────────────
  group('Expense review transitions (approve / reject)', () {
    test('a PENDING claim can be approved', () {
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusPending,
          targetStatus: expenseStatusApproved,
        ),
        isNull,
      );
    });

    test('a PENDING claim can be rejected', () {
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusPending,
          targetStatus: expenseStatusRejected,
        ),
        isNull,
      );
    });

    test('an ALREADY APPROVED claim cannot be approved a second time', () {
      final refusal = expenseTransitionRefusal(
        currentStatus: expenseStatusApproved,
        targetStatus: expenseStatusApproved,
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('already been reviewed'));
    });

    test('an ALREADY REJECTED claim cannot be rejected a second time', () {
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusRejected,
          targetStatus: expenseStatusRejected,
        ),
        isNotNull,
      );
    });

    test('an ALREADY PAID claim cannot be approved or rejected', () {
      for (final target in [expenseStatusApproved, expenseStatusRejected]) {
        expect(
          expenseTransitionRefusal(
            currentStatus: expenseStatusPaid,
            targetStatus: target,
          ),
          isNotNull,
          reason: 'paid → $target must be refused',
        );
      }
    });

    test('a PAID claim cannot be rejected (the workflow never goes back)', () {
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusPaid,
          targetStatus: expenseStatusRejected,
        ),
        isNotNull,
      );
    });

    test('the refusal names the status the client actually read', () {
      final refusal = expenseTransitionRefusal(
        currentStatus: expenseStatusApproved,
        targetStatus: expenseStatusApproved,
      );
      expect(refusal, contains(expenseStatusApproved));
    });

    test('a non-guarded transition is left alone', () {
      // A member editing their own pending claim carries no target status.
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusPending,
          targetStatus: 'edited',
        ),
        isNull,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  group('Reimbursement transitions (mark paid)', () {
    test('an APPROVED claim can be reimbursed', () {
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusApproved,
          targetStatus: expenseStatusPaid,
        ),
        isNull,
      );
    });

    test('a PENDING claim cannot be reimbursed before review', () {
      final refusal = expenseTransitionRefusal(
        currentStatus: expenseStatusPending,
        targetStatus: expenseStatusPaid,
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('not awaiting reimbursement'));
    });

    test('a REJECTED claim cannot be reimbursed', () {
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusRejected,
          targetStatus: expenseStatusPaid,
        ),
        isNotNull,
      );
    });

    test('a SECOND reimbursement of the same claim is refused', () {
      // The state the losing racer reads after the first reimbursement commits.
      expect(
        expenseTransitionRefusal(
          currentStatus: expenseStatusPaid,
          targetStatus: expenseStatusPaid,
        ),
        isNotNull,
      );
    });

    test('a STALE client still holding an approved expense is refused', () {
      // Two clients both opened an approved expense; the first reimbursed it, so
      // the second now reads `paid` and must not pay the claim again.
      const staleView = expenseStatusApproved; // what the tab still shows
      const liveStatus = expenseStatusPaid; // what is actually stored

      expect(
        expenseTransitionRefusal(
          currentStatus: staleView,
          targetStatus: expenseStatusPaid,
        ),
        isNull,
        reason: 'the stale view alone would have been allowed',
      );
      expect(
        expenseTransitionRefusal(
          currentStatus: liveStatus,
          targetStatus: expenseStatusPaid,
        ),
        isNotNull,
        reason: 'the transaction re-reads and refuses',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  group('Insufficient balance', () {
    test('an affordable reimbursement is allowed', () {
      expect(
        insufficientBalanceRefusal(balance: 500, amount: 120),
        isNull,
      );
    });

    test('a reimbursement that would empty the account exactly is allowed', () {
      expect(
        insufficientBalanceRefusal(balance: 120, amount: 120),
        isNull,
      );
    });

    test('a reimbursement that would overdraw is refused', () {
      final refusal = insufficientBalanceRefusal(balance: 100, amount: 120);
      expect(refusal, isNotNull);
      expect(refusal, contains('Insufficient balance'));
    });

    test('an empty account cannot fund any reimbursement', () {
      expect(insufficientBalanceRefusal(balance: 0, amount: 0.01), isNotNull);
    });

    test('the refusal names both the payment and the balance', () {
      final refusal = insufficientBalanceRefusal(balance: 100, amount: 120);
      expect(refusal, contains('120.00'));
      expect(refusal, contains('100.00'));
    });

    test('a signed outflow is measured by magnitude', () {
      // Transaction amounts arrive negative for money-out; the sign must not
      // turn an unaffordable payout into an affordable one.
      expect(insufficientBalanceRefusal(balance: 100, amount: -120), isNotNull);
      expect(insufficientBalanceRefusal(balance: 100, amount: -80), isNull);
    });

    test('two concurrent payouts cannot both pass against one balance', () {
      // Serialised by the house document: the second reads the decremented
      // balance after the first commits.
      const balance = 150.0;
      expect(insufficientBalanceRefusal(balance: balance, amount: 100), isNull);

      const afterFirst = balance - 100;
      expect(
        insufficientBalanceRefusal(balance: afterFirst, amount: 100),
        isNotNull,
        reason: 'the second payout would leave the account at -50',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  group('Bill mark paid — duplicate protection', () {
    final dueDate = DateTime(2026, 9, 15);

    test('an unpaid bill can be paid', () {
      expect(
        duplicateBillPaymentRefusal(
          isPaid: false,
          storedDueDate: dueDate,
          expectedDueDate: dueDate,
        ),
        isNull,
      );
    });

    test('a one-off bill already marked paid cannot be paid again', () {
      final refusal = duplicateBillPaymentRefusal(
        isPaid: true,
        storedDueDate: dueDate,
        expectedDueDate: dueDate,
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('already been marked paid'));
    });

    test('a RECURRING bill already rolled forward rejects a second tap', () {
      // The first tap rolled Sep 15 → Oct 15; the double tap still carries the
      // September due date, so it is recognised as a repeat of the same month.
      final refusal = duplicateBillPaymentRefusal(
        isPaid: false,
        storedDueDate: DateTime(2026, 10, 15),
        expectedDueDate: dueDate,
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('already been paid for that period'));
    });

    test('the NEXT month of a recurring bill can still be paid', () {
      expect(
        duplicateBillPaymentRefusal(
          isPaid: false,
          storedDueDate: DateTime(2026, 10, 15),
          expectedDueDate: DateTime(2026, 10, 15),
        ),
        isNull,
      );
    });

    test('a differing time of day on the same date is not a duplicate', () {
      expect(
        duplicateBillPaymentRefusal(
          isPaid: false,
          storedDueDate: DateTime(2026, 9, 15, 23, 59),
          expectedDueDate: DateTime(2026, 9, 15, 0, 1),
        ),
        isNull,
      );
    });

    test('a bill stored without a due date is not blocked on missing data', () {
      expect(
        duplicateBillPaymentRefusal(
          isPaid: false,
          storedDueDate: null,
          expectedDueDate: dueDate,
        ),
        isNull,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  group('Ledger submission key (deposit / direct payment idempotency)', () {
    test('a retry reuses the key, so the ledger row is only written once', () {
      final submission = LedgerSubmissionKey();
      var minted = 0;
      String generate() => 'key-${++minted}';

      final first = submission.key(generate);
      final retry = submission.key(generate);

      expect(retry, first, reason: 'a repeat must address the same row');
      expect(minted, 1, reason: 'only one key is ever minted per submission');
    });

    test('the key survives a failed attempt', () {
      final submission = LedgerSubmissionKey();
      var minted = 0;
      String generate() => 'key-${++minted}';

      submission.key(generate);
      // Submission failed — nothing was written, so the retry is the same
      // movement and must not be able to produce a second ledger row.
      expect(submission.isPending, isTrue);
      expect(submission.key(generate), 'key-1');
      expect(minted, 1);
    });

    test('clearing after a commit makes the next submission a new movement', () {
      final submission = LedgerSubmissionKey();
      var minted = 0;
      String generate() => 'key-${++minted}';

      expect(submission.key(generate), 'key-1');
      submission.clear();
      expect(submission.isPending, isFalse);
      expect(submission.key(generate), 'key-2');
    });

    test('a second deposit after a committed first one is not deduplicated', () {
      final submission = LedgerSubmissionKey();
      var minted = 0;
      String generate() => 'key-${++minted}';

      final depositOne = submission.key(generate);
      submission.clear();
      final depositTwo = submission.key(generate);

      expect(depositTwo, isNot(depositOne));
    });
  });
}
