import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/exceptions.dart';
import 'package:rental_ledger/core/errors/failure_codes.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/expenses/data/datasources/deposit_request_datasource.dart';
import 'package:rental_ledger/features/expenses/data/models/deposit_request_model.dart';
import 'package:rental_ledger/features/expenses/domain/entities/deposit_request_entity.dart';
import 'package:rental_ledger/features/expenses/domain/logic/deposit_request_guards.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Member-submitted deposits: a member files a Pending request for a deposit
/// THEY paid; the Treasurer approves (which is when the money reaches the
/// ledger, inside the data source's single transaction) or rejects it; the
/// member may cancel their own Pending request.
///
/// The Firestore transaction itself is exercised by the rules tests
/// (firestore-tests/rules.test.js); here a recording [DepositRequestDataSource]
/// fake stands in for it, so the notifiers' guards and orchestration are pinned.

final _now = DateTime(2026, 10);

final _treasurer = UserEntity(
  uid: 'treasurer-1',
  email: 'treasurer@example.com',
  displayName: 'Treasurer',
  createdAt: _now,
);

final _member = UserEntity(
  uid: 'member-1',
  email: 'member@example.com',
  displayName: 'Member',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'house-1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: _treasurer.uid,
  createdAt: _now,
);

DepositRequestEntity _request({
  String requestId = 'req-1',
  String submittedBy = 'member-1',
  String status = DepositRequestEntity.statusPending,
}) =>
    DepositRequestEntity(
      requestId: requestId,
      houseId: _house.houseId,
      amount: 300,
      paidByUserId: submittedBy,
      submittedBy: submittedBy,
      status: status,
      receiptUrl: 'https://storage.example.com/proof.jpg',
      createdAt: _now,
    );

class _RecordingRequests implements DepositRequestDataSource {
  int uploadCalls = 0;
  int createCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  int cancelCalls = 0;

  bool failUpload = false;

  /// Thrown by the next [createDepositRequest] (then cleared).
  Object? createFailure;

  /// Thrown by approve/reject — stands in for a lost race.
  Object? reviewFailure;

  final createdIds = <String>[];
  String? lastHouseId;
  double? lastAmount;
  String? lastSubmittedBy;
  String? lastReceiptUrl;
  String? lastNotes;
  String? lastPaymentMethod;
  String? lastPeriodLabel;
  String? lastPurpose;
  String? lastReviewedId;
  String? lastTreasurerId;
  String? lastReason;
  String? lastCancelledId;
  String? lastCancelUserId;

  @override
  Future<String> uploadReceipt({
    required String houseId,
    required String filePath,
  }) async {
    uploadCalls++;
    if (failUpload) throw const AppFirebaseException('upload exploded');
    return 'https://storage.example.com/receipts/$houseId/upload-$uploadCalls.jpg';
  }

  @override
  Future<DepositRequestModel> createDepositRequest({
    required String requestId,
    required String houseId,
    required double amount,
    required String submittedBy,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
    String? notes,
    required String receiptUrl,
  }) async {
    createCalls++;
    createdIds.add(requestId);
    lastHouseId = houseId;
    lastAmount = amount;
    lastSubmittedBy = submittedBy;
    lastReceiptUrl = receiptUrl;
    lastNotes = notes;
    lastPaymentMethod = paymentMethod;
    lastPeriodLabel = periodLabel;
    lastPurpose = purpose;
    final failure = createFailure;
    if (failure != null) {
      createFailure = null;
      throw failure;
    }
    return DepositRequestModel(
      requestId: requestId,
      houseId: houseId,
      amount: amount,
      paidByUserId: submittedBy,
      submittedBy: submittedBy,
      receiptUrl: receiptUrl,
      createdAt: _now,
    );
  }

  @override
  Future<void> approveDepositRequest(
    String requestId, {
    required String treasurerId,
  }) async {
    approveCalls++;
    lastReviewedId = requestId;
    lastTreasurerId = treasurerId;
    if (reviewFailure != null) throw reviewFailure!;
  }

  @override
  Future<void> rejectDepositRequest(
    String requestId, {
    required String treasurerId,
    String? reason,
  }) async {
    rejectCalls++;
    lastReviewedId = requestId;
    lastTreasurerId = treasurerId;
    lastReason = reason;
    if (reviewFailure != null) throw reviewFailure!;
  }

  @override
  Future<void> cancelDepositRequest(
    String requestId, {
    required String userId,
  }) async {
    cancelCalls++;
    lastCancelledId = requestId;
    lastCancelUserId = userId;
  }

  @override
  Stream<List<DepositRequestModel>> pendingDepositRequestsStream(
    String houseId,
  ) =>
      const Stream.empty();

  @override
  Stream<DepositRequestModel?> depositRequestStream(String requestId) =>
      const Stream.empty();
}

ProviderContainer _containerFor(
  _RecordingRequests ds, {
  required UserEntity user,
  HouseEntity? house,
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      currentHouseProvider.overrideWith((ref) => house ?? _house),
      depositRequestDataSourceProvider.overrideWithValue(ds),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('guards', () {
    test('only a Pending request is reviewable', () {
      expect(
        depositRequestReviewRefusal(
          currentStatus: DepositRequestEntity.statusPending,
        ),
        isNull,
      );
      expect(
        depositRequestReviewRefusal(
          currentStatus: DepositRequestEntity.statusApproved,
        ),
        contains('already been reviewed'),
      );
      expect(
        depositRequestReviewRefusal(
          currentStatus: DepositRequestEntity.statusRejected,
        ),
        isNotNull,
      );
    });

    test('only the submitter may cancel, and only while Pending', () {
      expect(
        depositRequestCancelRefusal(
          userId: 'member-1',
          submittedBy: 'member-1',
          currentStatus: DepositRequestEntity.statusPending,
        ),
        isNull,
      );
      expect(
        depositRequestCancelRefusal(
          userId: 'member-2',
          submittedBy: 'member-1',
          currentStatus: DepositRequestEntity.statusPending,
        ),
        contains('your own'),
      );
      expect(
        depositRequestCancelRefusal(
          userId: 'member-1',
          submittedBy: 'member-1',
          currentStatus: DepositRequestEntity.statusApproved,
        ),
        contains('pending'),
      );
    });

    test('the Treasurer sees every request; a member only their own', () {
      final requests = [
        _request(requestId: 'a'),
        _request(requestId: 'b', submittedBy: 'member-2'),
      ];
      expect(
        visibleDepositRequests(requests, userId: 'treasurer-1', isTreasurer: true)
            .map((r) => r.requestId),
        ['a', 'b'],
      );
      expect(
        visibleDepositRequests(requests, userId: 'member-1', isTreasurer: false)
            .map((r) => r.requestId),
        ['a'],
      );
      expect(
        visibleDepositRequests(requests, userId: null, isTreasurer: false),
        isEmpty,
      );
    });
  });

  group('DepositRequestModel', () {
    test('round-trips through the Firestore map', () {
      final model = DepositRequestModel(
        requestId: 'req-1',
        houseId: 'house-1',
        amount: 120.5,
        paidByUserId: 'member-1',
        submittedBy: 'member-1',
        paymentMethod: 'Cash',
        periodLabel: '2026-10',
        purpose: 'Monthly Rental',
        notes: 'Oct rent',
        receiptUrl: 'https://storage.example.com/proof.jpg',
        createdAt: DateTime(2026, 10, 1, 9),
      );
      final map = model.toMap();
      expect(map['status'], 'Pending');
      expect(map['reviewedBy'], isNull);
      expect(map['transactionId'], isNull);
      expect(map['createdAt'], isA<Timestamp>());

      final back = DepositRequestModel.fromMap(map, 'req-1');
      expect(back.amount, 120.5);
      expect(back.paidByUserId, 'member-1');
      expect(back.purpose, 'Monthly Rental');
      expect(back.isPending, isTrue);
      expect(back.createdAt, DateTime(2026, 10, 1, 9));
    });

    test('reads review fields and falls back to the submitter as payer', () {
      final back = DepositRequestModel.fromMap({
        'houseId': 'house-1',
        'amount': 50,
        'submittedBy': 'member-1',
        'status': 'Approved',
        'reviewedBy': 'treasurer-1',
        'reviewedAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
        'transactionId': 'req-9',
      }, 'req-9');
      expect(back.paidByUserId, 'member-1');
      expect(back.isApproved, isTrue);
      expect(back.reviewedAt, DateTime(2026, 10, 2));
      expect(back.transactionId, 'req-9');
    });
  });

  group('Submit Deposit (member)', () {
    test('uploads proof first, then files ONE Pending request for themselves',
        () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);
      final notifier = container.read(submitDepositRequestProvider.notifier);
      notifier.setProofPath('/tmp/proof.jpg');

      final error = await notifier.submit(
        amount: 300,
        notes: '  Oct rent  ',
        paymentMethod: 'Bank Transfer',
        periodLabel: '2026-10',
        purpose: 'Monthly Rental',
      );

      expect(error, isNull);
      expect(ds.uploadCalls, 1);
      expect(ds.createCalls, 1);
      expect(ds.lastHouseId, _house.houseId);
      expect(ds.lastAmount, 300);
      // The payer is never chosen: it is the signed-in member.
      expect(ds.lastSubmittedBy, _member.uid);
      expect(ds.lastReceiptUrl, startsWith('https://storage.example.com'));
      expect(ds.lastNotes, 'Oct rent');
      expect(ds.lastPaymentMethod, 'Bank Transfer');
      expect(ds.lastPeriodLabel, '2026-10');
      expect(ds.lastPurpose, 'Monthly Rental');
      expect(notifier.hasProof, isFalse);
    });

    test('no proof → validation error, nothing uploaded or filed', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);

      final error = await container
          .read(submitDepositRequestProvider.notifier)
          .submit(amount: 100);

      expect(
        error,
        'A receipt or proof image is required to submit a deposit.',
      );
      expect(ds.uploadCalls, 0);
      expect(ds.createCalls, 0);
    });

    test('upload failure → no request, real error surfaced, proof kept',
        () async {
      final ds = _RecordingRequests()..failUpload = true;
      final container = _containerFor(ds, user: _member);
      final notifier = container.read(submitDepositRequestProvider.notifier);
      notifier.setProofPath('/tmp/proof.jpg');

      final error = await notifier.submit(amount: 100);

      expect(error, 'upload exploded');
      expect(ds.createCalls, 0);
      expect(notifier.hasProof, isTrue);
    });

    test('a retry after a failed write reuses the SAME request id and the '
        'already-uploaded proof', () async {
      final ds = _RecordingRequests()
        ..createFailure = const AppFirebaseException('write exploded');
      final container = _containerFor(ds, user: _member);
      final notifier = container.read(submitDepositRequestProvider.notifier);
      notifier.setProofPath('/tmp/proof.jpg');

      expect(await notifier.submit(amount: 100), 'write exploded');
      expect(notifier.hasProof, isTrue);

      expect(await notifier.submit(amount: 100), isNull);
      expect(ds.createCalls, 2);
      expect(ds.createdIds[0], ds.createdIds[1],
          reason: 'the retry is the same submission, not a second request');
      expect(ds.uploadCalls, 1, reason: 'the proof is not uploaded twice');
    });

    test('each successful submission gets a fresh request id', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);
      final notifier = container.read(submitDepositRequestProvider.notifier);

      notifier.setProofPath('/tmp/a.jpg');
      await notifier.submit(amount: 100);
      notifier.setProofPath('/tmp/b.jpg');
      await notifier.submit(amount: 200);

      expect(ds.createdIds, hasLength(2));
      expect(ds.createdIds[0], isNot(ds.createdIds[1]));
    });

    test('a double tap while in flight files only one request', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);
      final notifier = container.read(submitDepositRequestProvider.notifier);
      notifier.setProofPath('/tmp/proof.jpg');

      final results = await Future.wait([
        notifier.submit(amount: 100),
        notifier.submit(amount: 100),
      ]);

      expect(results, [isNull, isNull]);
      expect(ds.createCalls, 1);
    });
  });

  group('Review (Treasurer)', () {
    test('the Treasurer approves: data source called with request + reviewer',
        () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _treasurer);

      final error = await container
          .read(reviewDepositRequestProvider.notifier)
          .approve(_request());

      expect(error, isNull);
      expect(ds.approveCalls, 1);
      expect(ds.lastReviewedId, 'req-1');
      expect(ds.lastTreasurerId, _treasurer.uid);
    });

    test('a member CANNOT approve or reject — nothing reaches the data source',
        () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);
      final notifier = container.read(reviewDepositRequestProvider.notifier);

      expect(
        await notifier.approve(_request()),
        'Only the Treasurer can review a deposit.',
      );
      expect(
        await notifier.reject(_request(), reason: 'no'),
        'Only the Treasurer can review a deposit.',
      );
      expect(ds.approveCalls, 0);
      expect(ds.rejectCalls, 0);
    });

    test('reject trims the reason and drops a blank one', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _treasurer);
      final notifier = container.read(reviewDepositRequestProvider.notifier);

      await notifier.reject(_request(), reason: '  Blurry proof  ');
      expect(ds.lastReason, 'Blurry proof');

      await notifier.reject(_request(), reason: '   ');
      expect(ds.lastReason, isNull);
      expect(ds.approveCalls, 0);
    });

    test('a lost race (already reviewed) surfaces the stable code', () async {
      final ds = _RecordingRequests()
        ..reviewFailure = const ConflictException(
          'already reviewed',
          code: FailureCodes.depositRequestAlreadyReviewed,
        );
      final container = _containerFor(ds, user: _treasurer);

      final error = await container
          .read(reviewDepositRequestProvider.notifier)
          .approve(_request());

      expect(error, FailureCodes.depositRequestAlreadyReviewed);
    });

    test('an already-reviewed request is refused without calling the server',
        () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _treasurer);

      final error = await container
          .read(reviewDepositRequestProvider.notifier)
          .approve(_request(status: DepositRequestEntity.statusApproved));

      expect(error, FailureCodes.depositRequestAlreadyReviewed);
      expect(ds.approveCalls, 0);
    });
  });

  group('Cancel (member)', () {
    test('the submitter cancels their own Pending request', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);

      final error = await container
          .read(cancelDepositRequestProvider.notifier)
          .cancel(_request());

      expect(error, isNull);
      expect(ds.cancelCalls, 1);
      expect(ds.lastCancelledId, 'req-1');
      expect(ds.lastCancelUserId, _member.uid);
    });

    test('someone else\'s request cannot be cancelled', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);

      final error = await container
          .read(cancelDepositRequestProvider.notifier)
          .cancel(_request(submittedBy: 'member-2'));

      expect(error, 'You can only cancel your own deposit request.');
      expect(ds.cancelCalls, 0);
    });

    test('a reviewed request cannot be cancelled', () async {
      final ds = _RecordingRequests();
      final container = _containerFor(ds, user: _member);

      final error = await container
          .read(cancelDepositRequestProvider.notifier)
          .cancel(_request(status: DepositRequestEntity.statusRejected));

      expect(error, 'Only pending deposit requests can be cancelled.');
      expect(ds.cancelCalls, 0);
    });
  });
}
