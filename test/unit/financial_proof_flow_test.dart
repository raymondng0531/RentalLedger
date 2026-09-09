import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/exceptions.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/expenses/data/datasources/expense_ledger_datasource.dart';
import 'package:rental_ledger/features/expenses/data/models/bill_model.dart';
import 'package:rental_ledger/features/expenses/data/models/transaction_model.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Success-path orchestration for the financial actions that move real money:
/// Record Deposit / Record Direct Payment / Mark a Bill Paid.
///
/// The permission guards are covered separately (financial_permission_test).
/// Here a recording [ExpenseLedgerDataSource] fake stands in for Firestore so
/// we can assert the rules that the guards alone cannot reach:
///   - proof is uploaded BEFORE the ledger write, and the resolved URL is the
///     one forwarded to the transaction;
///   - exactly ONE ledger write per action (one money movement = one row);
///   - every new attribution field (paidByUserId / paymentMethod / periodLabel
///     / purpose / categoryId) reaches the ledger untouched;
///   - an upload failure returns the real error and NEVER creates a transaction,
///     leaving the staged proof in place so the user can retry.
const _depositProofMessage =
    'A receipt or proof image is required to record a deposit.';
const _directPaymentProofMessage =
    'A receipt or proof image is required to record a direct payment.';

final _now = DateTime(2026, 9);

final _treasurerUser = UserEntity(
  uid: 'treasurer-1',
  email: 'treasurer@example.com',
  displayName: 'Treasurer',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'house-1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: _treasurerUser.uid,
  createdAt: _now,
);

BillEntity _bill({
  double? amount = 99,
  bool isRecurring = false,
}) =>
    BillEntity(
      billId: 'bill-1',
      houseId: _house.houseId,
      title: 'Internet',
      amount: amount,
      dueDate: DateTime(2026, 10),
      isRecurring: isRecurring,
      createdAt: _now,
    );

/// Records the ledger calls a financial action makes so tests can assert
/// call counts and forwarded fields.
class _RecordingLedger implements ExpenseLedgerDataSource {
  int uploadCalls = 0;
  int depositCalls = 0;
  int directPaymentCalls = 0;
  int markBillPaidCalls = 0;

  /// When true, [uploadReceipt] throws instead of succeeding.
  bool failUpload = false;
  AppFirebaseException uploadError =
      const AppFirebaseException('upload exploded');

  // Captured arguments from the LAST ledger call.
  String? lastHouseId;
  String? lastPerformedBy;
  double? lastAmount;
  String? lastReceiptUrl;
  String? lastPaidByUserId;
  String? lastPaymentMethod;
  String? lastPeriodLabel;
  String? lastPurpose;
  String? lastCategoryId;
  String? lastBillId;
  BillEntity? lastBill;

  @override
  Future<String> uploadReceipt({
    required String houseId,
    required String filePath,
  }) async {
    uploadCalls++;
    if (failUpload) throw uploadError;
    return 'https://storage.example.com/receipts/$houseId/upload-$uploadCalls.jpg';
  }

  @override
  Future<TransactionModel> recordDeposit({
    required String houseId,
    required double amount,
    required String performedBy,
    String? notes,
    String? receiptUrl,
    String? paidByUserId,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
  }) async {
    depositCalls++;
    lastHouseId = houseId;
    lastAmount = amount;
    lastPerformedBy = performedBy;
    lastReceiptUrl = receiptUrl;
    lastPaidByUserId = paidByUserId;
    lastPaymentMethod = paymentMethod;
    lastPeriodLabel = periodLabel;
    lastPurpose = purpose;
    return _tx(type: 'Deposit', amount: amount, performedBy: performedBy);
  }

  @override
  Future<TransactionModel> recordDirectPayment({
    required String houseId,
    required double amount,
    required String performedBy,
    String? notes,
    String? receiptUrl,
    String? paymentMethod,
    String? periodLabel,
    String? categoryId,
  }) async {
    directPaymentCalls++;
    lastHouseId = houseId;
    lastAmount = amount;
    lastPerformedBy = performedBy;
    lastReceiptUrl = receiptUrl;
    lastPaymentMethod = paymentMethod;
    lastPeriodLabel = periodLabel;
    lastCategoryId = categoryId;
    return _tx(type: 'Direct Payment', amount: amount, performedBy: performedBy);
  }

  @override
  Future<void> markBillPaid(
    String billId,
    BillEntity bill, {
    required String performedBy,
    String? receiptUrl,
    String? paymentMethod,
    String? periodLabel,
  }) async {
    markBillPaidCalls++;
    lastBillId = billId;
    lastBill = bill;
    lastPerformedBy = performedBy;
    lastReceiptUrl = receiptUrl;
    lastPaymentMethod = paymentMethod;
    lastPeriodLabel = periodLabel;
  }

  TransactionModel _tx({
    required String type,
    required double amount,
    required String performedBy,
  }) =>
      TransactionModel(
        transactionId: 'tx-recorded',
        houseId: _house.houseId,
        type: type,
        amount: amount,
        performedBy: performedBy,
        createdAt: _now,
      );

  // ── Bill-template methods: not exercised by these tests. ──
  @override
  Future<BillModel> createBill(
          {required String houseId,
          required String title,
          double? amount,
          required DateTime dueDate,
          String categoryId = 'utilities',
          bool isRecurring = false}) async =>
      throw UnimplementedError('createBill not used in this test');

  @override
  Future<void> updateBill(String billId, Map<String, dynamic> updates) async =>
      throw UnimplementedError('updateBill not used in this test');

  @override
  Future<void> deleteBill(String billId) async =>
      throw UnimplementedError('deleteBill not used in this test');
}

/// A container overriding the signed-in user, house, and the ledger seam.
ProviderContainer _containerFor(_RecordingLedger ledger) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => _treasurerUser),
      currentHouseProvider.overrideWith((ref) => _house),
      expenseLedgerProvider.overrideWithValue(ledger),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Record Deposit — proof + one transaction + attribution', () {
    test('proof uploads first, then ONE deposit records with every field',
        () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);
      final notifier = container.read(depositProvider.notifier);
      notifier.setProofPath('/tmp/deposit-proof.jpg');

      final error = await notifier.deposit(
        amount: 1200,
        notes: 'Sep rental contribution',
        paidByUserId: 'member-9',
        paymentMethod: 'Bank Transfer',
        periodLabel: '2026-09',
        purpose: 'Monthly Rental',
      );

      expect(error, isNull);
      // Exactly one upload and exactly ONE ledger write.
      expect(ledger.uploadCalls, 1);
      expect(ledger.depositCalls, 1);
      // The uploaded URL is the receipt attached to the transaction.
      expect(ledger.lastReceiptUrl, startsWith('https://storage.example.com'));
      // Attribution fields forwarded untouched.
      expect(ledger.lastHouseId, _house.houseId);
      expect(ledger.lastAmount, 1200);
      expect(ledger.lastPaidByUserId, 'member-9');
      expect(ledger.lastPaymentMethod, 'Bank Transfer');
      expect(ledger.lastPeriodLabel, '2026-09');
      expect(ledger.lastPurpose, 'Monthly Rental');
      // performedBy = the recorder (the Treasurer), distinct from the payer.
      expect(ledger.lastPerformedBy, _treasurerUser.uid);
      // Staged proof is consumed only after a successful upload.
      expect(notifier.hasProof, isFalse);
    });

    test('no proof selected → validation error and NO upload or transaction',
        () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);

      final error = await container
          .read(depositProvider.notifier)
          .deposit(amount: 100, notes: 'Top-up');

      expect(error, _depositProofMessage);
      expect(ledger.uploadCalls, 0);
      expect(ledger.depositCalls, 0);
    });

    test('upload failure → NO transaction, real error surfaced, proof kept',
        () async {
      final ledger = _RecordingLedger()..failUpload = true;
      final container = _containerFor(ledger);
      final notifier = container.read(depositProvider.notifier);
      notifier.setProofPath('/tmp/deposit-proof.jpg');

      final error = await notifier.deposit(amount: 500, notes: 'Top-up');

      expect(error, 'upload exploded',
          reason: 'the underlying upload reason must reach the user');
      expect(ledger.depositCalls, 0,
          reason: 'a failed upload must never create a transaction');
      expect(notifier.hasProof, isTrue,
          reason: 'staged proof is retained so the user can retry');
    });
  });

  group('Record Direct Payment — proof + one transaction + category', () {
    test('proof uploads first, then ONE direct payment records with category',
        () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);
      final notifier = container.read(directPaymentProvider.notifier);
      notifier.setProofPath('/tmp/payment-proof.jpg');

      final error = await notifier.payDirectly(
        amount: 350,
        notes: 'Electricity',
        categoryId: 'utilities',
        paymentMethod: 'Card',
        periodLabel: '2026-09',
      );

      expect(error, isNull);
      expect(ledger.uploadCalls, 1);
      expect(ledger.directPaymentCalls, 1);
      expect(ledger.lastReceiptUrl, startsWith('https://storage.example.com'));
      expect(ledger.lastAmount, 350);
      expect(ledger.lastCategoryId, 'utilities');
      expect(ledger.lastPaymentMethod, 'Card');
      expect(ledger.lastPeriodLabel, '2026-09');
      expect(ledger.lastPerformedBy, _treasurerUser.uid);
    });

    test('no proof selected → validation error and NO transaction', () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);

      final error = await container
          .read(directPaymentProvider.notifier)
          .payDirectly(amount: 50, notes: 'Repair');

      expect(error, _directPaymentProofMessage);
      expect(ledger.uploadCalls, 0);
      expect(ledger.directPaymentCalls, 0);
    });

    test('upload failure → NO transaction, real error surfaced', () async {
      final ledger = _RecordingLedger()..failUpload = true;
      final container = _containerFor(ledger);
      final notifier = container.read(directPaymentProvider.notifier);
      notifier.setProofPath('/tmp/payment-proof.jpg');

      final error = await notifier.payDirectly(amount: 50, notes: 'Repair');

      expect(error, 'upload exploded');
      expect(ledger.directPaymentCalls, 0);
    });
  });

  group('Mark Bill Paid — monthly proof + one transaction per month', () {
    test('amount-bearing bill without proof throws before any upload', () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);

      await expectLater(
        container.read(billActionsProvider.notifier).markPaid(_bill()),
        throwsA(isA<AppFirebaseException>()),
      );
      expect(ledger.uploadCalls, 0);
      expect(ledger.markBillPaidCalls, 0);
    });

    test('amount-bearing bill with proof → ONE ledger write with that month',
        () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);
      final bill = _bill(isRecurring: true);

      await container.read(billActionsProvider.notifier).markPaid(
            bill,
            proofPath: '/tmp/bill-proof.jpg',
            paymentMethod: 'Bank Transfer',
            periodLabel: '2026-09',
          );

      // Recurring roll-forward must not create a second transaction: exactly
      // one markBillPaid call for this month's payment.
      expect(ledger.uploadCalls, 1);
      expect(ledger.markBillPaidCalls, 1);
      expect(ledger.lastBillId, bill.billId);
      expect(ledger.lastBill, same(bill));
      expect(ledger.lastReceiptUrl, startsWith('https://storage.example.com'));
      expect(ledger.lastPaymentMethod, 'Bank Transfer');
      expect(ledger.lastPeriodLabel, '2026-09');
      expect(ledger.lastPerformedBy, _treasurerUser.uid);
    });

    test('reminder-only bill (no amount) needs no proof, writes no receipt',
        () async {
      final ledger = _RecordingLedger();
      final container = _containerFor(ledger);

      await container
          .read(billActionsProvider.notifier)
          .markPaid(_bill(amount: null));

      expect(ledger.uploadCalls, 0);
      expect(ledger.markBillPaidCalls, 1);
      expect(ledger.lastReceiptUrl, isNull);
    });
  });
}
