import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/transaction_entity.dart';

TransactionEntity _tx(String type, {double amount = 100}) {
  return TransactionEntity(
    transactionId: 'tx1',
    houseId: 'house1',
    type: type,
    amount: amount,
    performedBy: 'user1',
    createdAt: DateTime(2026, 7, 1),
  );
}

void main() {
  group('TransactionEntity type helpers', () {
    test('isDeposit', () {
      expect(_tx('Deposit').isDeposit, isTrue);
    });

    test('isReimbursement', () {
      expect(_tx('Reimbursement').isReimbursement, isTrue);
    });

    test('isDirectPayment', () {
      expect(_tx('Direct Payment').isDirectPayment, isTrue);
    });

    test('isAdjustment', () {
      expect(_tx('Adjustment').isAdjustment, isTrue);
    });
  });

  group('TransactionEntity flow classification', () {
    test('Deposit is inflow', () {
      expect(_tx('Deposit').isInflow, isTrue);
      expect(_tx('Deposit').isOutflow, isFalse);
    });

    test('Reimbursement is outflow', () {
      expect(_tx('Reimbursement').isInflow, isFalse);
      expect(_tx('Reimbursement').isOutflow, isTrue);
    });

    test('Direct Payment is outflow', () {
      expect(_tx('Direct Payment').isOutflow, isTrue);
    });
  });
}
