import '../entities/category_entity.dart';
import '../entities/expense_entity.dart';

/// Abstract repository for expense operations.
abstract class ExpenseRepository {
  /// Creates a new expense.
  Future<ExpenseEntity> createExpense(ExpenseEntity expense);

  /// Updates an existing expense (only while pending).
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense);

  /// Deletes an expense (only while pending).
  Future<void> deleteExpense(String expenseId);

  /// Fetches a single expense by ID.
  Future<ExpenseEntity?> getExpense(String expenseId);

  /// Fetches all expenses for a house, newest first.
  Future<List<ExpenseEntity>> getExpenses(String houseId, {String? status});

  /// Approves a pending expense (Treasurer only).
  Future<ExpenseEntity> approveExpense(
      String expenseId, String treasurerId);

  /// Rejects a pending expense (Treasurer only).
  Future<ExpenseEntity> rejectExpense(
      String expenseId, String treasurerId, {String? reason});

  /// Marks an approved expense as paid (Treasurer only).
  Future<ExpenseEntity> markPaid(
      String expenseId, String treasurerId);

  /// Fetches categories available for this house.
  Future<List<CategoryEntity>> getCategories(String houseId);

  /// Seeds default categories for a new house.
  Future<void> seedDefaultCategories(String houseId);
}
