import '../../../../core/errors/failures.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_datasource.dart';

/// Implementation of [ExpenseRepository] backed by Firestore.
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({required ExpenseRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final ExpenseRemoteDataSource _remote;

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    try {
      return await _remote.createExpense(expense);
    } catch (e) {
      throw FirebaseFailure('Failed to submit expense: ${e.toString()}');
    }
  }

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) async {
    if (!expense.isEditable) {
      throw const PermissionFailure('Can only edit pending expenses.');
    }
    try {
      return await _remote.updateExpense(expense);
    } catch (e) {
      throw FirebaseFailure('Failed to update expense: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    try {
      // Fetch first to check status.
      final expense = await _remote.getExpense(expenseId);
      if (expense != null && !expense.isDeletable) {
        throw const PermissionFailure('Can only delete pending expenses.');
      }
      await _remote.deleteExpense(expenseId);
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Failed to delete expense: ${e.toString()}');
    }
  }

  @override
  Future<ExpenseEntity?> getExpense(String expenseId) async {
    try {
      return await _remote.getExpense(expenseId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ExpenseEntity>> getExpenses(String houseId,
      {String? status}) async {
    try {
      return await _remote.getExpenses(houseId, status: status);
    } catch (e) {
      throw FirebaseFailure('Failed to load expenses: ${e.toString()}');
    }
  }

  @override
  Future<ExpenseEntity> approveExpense(
      String expenseId, String treasurerId) async {
    try {
      return await _remote.approveExpense(expenseId, treasurerId);
    } catch (e) {
      throw FirebaseFailure('Failed to approve: ${e.toString()}');
    }
  }

  @override
  Future<ExpenseEntity> rejectExpense(
      String expenseId, String treasurerId, {String? reason}) async {
    try {
      return await _remote.rejectExpense(expenseId, treasurerId, reason: reason);
    } catch (e) {
      throw FirebaseFailure('Failed to reject: ${e.toString()}');
    }
  }

  @override
  Future<ExpenseEntity> markPaid(
      String expenseId, String treasurerId) async {
    try {
      return await _remote.markPaid(expenseId, treasurerId);
    } catch (e) {
      throw FirebaseFailure('Failed to mark paid: ${e.toString()}');
    }
  }

  @override
  Future<List<CategoryEntity>> getCategories(String houseId) async {
    try {
      return await _remote.getCategories(houseId);
    } catch (e) {
      return CategoryEntity.defaults;
    }
  }

  @override
  Future<void> seedDefaultCategories(String houseId) async {
    try {
      await _remote.seedDefaultCategories(houseId);
    } catch (e) {
      // Non-critical.
    }
  }
}
