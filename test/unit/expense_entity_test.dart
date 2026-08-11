import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';

ExpenseEntity _expense({String status = 'pending', String paymentSource = 'personal'}) {
  return ExpenseEntity(
    expenseId: 'exp1',
    houseId: 'house1',
    purchasedBy: 'user1',
    title: 'Test Expense',
    categoryId: 'food',
    amount: 25.50,
    paymentSource: paymentSource,
    status: status,
    createdAt: DateTime(2026, 7, 1),
  );
}

void main() {
  group('ExpenseEntity status helpers', () {
    test('isPending', () {
      expect(_expense(status: 'pending').isPending, isTrue);
      expect(_expense(status: 'approved').isPending, isFalse);
    });

    test('isApproved', () {
      expect(_expense(status: 'approved').isApproved, isTrue);
      expect(_expense(status: 'pending').isApproved, isFalse);
    });

    test('isPaid', () {
      expect(_expense(status: 'paid').isPaid, isTrue);
    });

    test('isRejected', () {
      expect(_expense(status: 'rejected').isRejected, isTrue);
    });

    test('isEditable only when pending', () {
      expect(_expense(status: 'pending').isEditable, isTrue);
      expect(_expense(status: 'approved').isEditable, isFalse);
      expect(_expense(status: 'paid').isEditable, isFalse);
    });

    test('isDeletable only when pending', () {
      expect(_expense(status: 'pending').isDeletable, isTrue);
      expect(_expense(status: 'rejected').isDeletable, isFalse);
    });
  });

  group('ExpenseEntity payment source', () {
    test('isPersonal', () {
      expect(_expense(paymentSource: 'personal').isPersonal, isTrue);
    });

    test('isCentral', () {
      expect(_expense(paymentSource: 'central').isCentral, isTrue);
    });
  });

  group('ExpenseEntity equality', () {
    test('same ID means equal', () {
      final a = _expense();
      final b = _expense();
      expect(a, equals(b));
    });

    test('different ID means not equal', () {
      final a = _expense();
      final b = _expense();
      final diff = ExpenseEntity(
        expenseId: 'exp2',
        houseId: b.houseId,
        purchasedBy: b.purchasedBy,
        title: b.title,
        categoryId: b.categoryId,
        amount: b.amount,
        paymentSource: b.paymentSource,
        createdAt: b.createdAt,
      );
      expect(a, isNot(equals(diff)));
    });
  });

  group('ExpenseEntity.copyWith', () {
    test('updates only specified fields', () {
      final original = _expense();
      final updated = original.copyWith(status: 'approved');
      expect(updated.status, 'approved');
      expect(updated.title, original.title);
      expect(updated.expenseId, original.expenseId);
    });
  });
}
