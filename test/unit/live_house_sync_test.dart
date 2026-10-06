import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/members/data/datasources/house_remote_datasource.dart';
import 'package:rental_ledger/features/members/data/models/house_model.dart';
import 'package:rental_ledger/features/members/data/repositories/house_repository_impl.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Live house sync: a change to the current house's document (a Treasurer
/// transfer, a rename, a new invite code) made on ANOTHER device must reach
/// this one — and everything reading [currentHouseProvider] — without a
/// page reload.

final _created = DateTime(2026, 10);

HouseModel _house({
  String houseId = 'house-1',
  String name = 'Sunset Villa',
  String treasurerId = 'bob',
  double balance = 0,
}) =>
    HouseModel(
      houseId: houseId,
      houseName: name,
      inviteCode: 'DEMO42',
      treasurerId: treasurerId,
      balance: balance,
      createdAt: _created,
    );

/// Resolves the user's house, then lets the test push document snapshots.
class _FakeRemote implements HouseRemoteDataSource {
  _FakeRemote(this.initial);

  final HouseModel initial;
  final docs = StreamController<HouseModel?>.broadcast();
  final followed = <String>[];

  @override
  Future<HouseModel?> findHouseByUserId(String userId) async => initial;

  @override
  Stream<HouseModel?> houseStream(String houseId) {
    followed.add(houseId);
    return docs.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('houseDetailsDiffer', () {
    test('a new Treasurer, name or house is a visible change', () {
      expect(houseDetailsDiffer(_house(), _house(treasurerId: 'alice')), isTrue);
      expect(houseDetailsDiffer(_house(), _house(name: 'Villa 2')), isTrue);
      expect(houseDetailsDiffer(_house(), _house(houseId: 'house-2')), isTrue);
      expect(houseDetailsDiffer(_house(), null), isTrue);
      expect(houseDetailsDiffer(null, null), isFalse);
    });

    test('a balance change alone is NOT (the dashboard reads it live)', () {
      expect(houseDetailsDiffer(_house(), _house(balance: 500)), isFalse);
    });
  });

  group('HouseRepositoryImpl follows the current house document', () {
    test('a Treasurer transfer from another device updates currentHouse',
        () async {
      final remote = _FakeRemote(_house());
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      addTearDown(repo.dispose);

      await repo.loadUserHouse('bob');
      expect(remote.followed, ['house-1']);

      var notified = 0;
      repo.currentHouseNotifier.addListener(() => notified++);

      remote.docs.add(_house(treasurerId: 'alice'));
      await _settle();

      expect(repo.currentHouse!.treasurerId, 'alice');
      expect(notified, 1,
          reason: 'same house id, new Treasurer — listeners must hear it');
    });

    test('a balance-only snapshot does not churn listeners', () async {
      final remote = _FakeRemote(_house());
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      addTearDown(repo.dispose);
      await repo.loadUserHouse('bob');

      var notified = 0;
      repo.currentHouseNotifier.addListener(() => notified++);
      remote.docs.add(_house(balance: 999));
      await _settle();

      expect(notified, 0);
    });

    test('clearing the house stops following it', () async {
      final remote = _FakeRemote(_house());
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      addTearDown(repo.dispose);
      await repo.loadUserHouse('bob');

      await repo.clearCurrentHouse();
      remote.docs.add(_house(treasurerId: 'alice'));
      await _settle();

      expect(repo.currentHouse, isNull);
    });
  });

  group('currentHouseProvider is live', () {
    test('re-evaluates when the repository house changes', () async {
      final remote = _FakeRemote(_house());
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      addTearDown(repo.dispose);
      final container = ProviderContainer(
        overrides: [houseRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final seen = <String?>[];
      container.listen<HouseEntity?>(
        currentHouseProvider,
        (_, next) => seen.add(next?.treasurerId),
        fireImmediately: true,
      );
      expect(seen, [null]);

      await repo.loadUserHouse('bob');
      container.read(currentHouseProvider); // flush the invalidation
      remote.docs.add(_house(treasurerId: 'alice'));
      await _settle();
      container.read(currentHouseProvider);

      expect(seen, [null, 'bob', 'alice']);
    });
  });
}
