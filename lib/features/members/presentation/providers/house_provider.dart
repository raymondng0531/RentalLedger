import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/house_remote_datasource.dart';
import '../../data/repositories/house_repository_impl.dart';
import '../../domain/entities/house_entity.dart';
import '../../domain/entities/house_member_entity.dart';
import '../../domain/repositories/house_repository.dart';

// ───── Repository Provider ─────

final houseRepositoryProvider = Provider<HouseRepository>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) {
    return _NoOpHouseRepository();
  }

  final repo = HouseRepositoryImpl(
    remoteDataSource: HouseRemoteDataSource(),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Call after auth is ready to load the user's house.
final loadUserHouseProvider = Provider.autoDispose<void>((ref) {
  // Intentionally left as a trigger — called manually.
});

// ───── Current House Provider ─────

final currentHouseProvider = Provider<HouseEntity?>((ref) {
  return ref.watch(houseRepositoryProvider).currentHouse;
});

final hasHouseProvider = Provider<bool>((ref) {
  return ref.watch(houseRepositoryProvider).hasHouse;
});

// ───── User Houses (for the switcher) ─────

final userHousesProvider = FutureProvider<List<HouseEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.watch(houseRepositoryProvider);
  return repo.getUserHouses(user.uid);
});

// ───── Switch House Provider ─────

final switchHouseProvider =
    AutoDisposeAsyncNotifierProvider<SwitchHouseNotifier, void>(
        SwitchHouseNotifier.new);

class SwitchHouseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> switchTo(String houseId) async {
    state = const AsyncValue.loading();
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return 'Not authenticated.';

      final repo = ref.read(houseRepositoryProvider);
      await repo.switchHouse(user.uid, houseId);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Create House Provider ─────

final createHouseProvider =
    AutoDisposeAsyncNotifierProvider<CreateHouseNotifier, void>(
        CreateHouseNotifier.new);

class CreateHouseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> createHouse(String houseName, String treasurerId) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(houseRepositoryProvider);
      await repo.createHouse(houseName.trim(), treasurerId);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Join House Provider ─────

final joinHouseProvider =
    AutoDisposeAsyncNotifierProvider<JoinHouseNotifier, void>(
        JoinHouseNotifier.new);

class JoinHouseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> joinHouse(String inviteCode, String userId) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(houseRepositoryProvider);
      await repo.joinHouse(inviteCode.trim().toUpperCase(), userId);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Members Provider ─────

final membersProvider = FutureProvider<List<HouseMemberEntity>>((ref) {
  final house = ref.watch(currentHouseProvider);
  if (house == null) return [];

  final repo = ref.watch(houseRepositoryProvider);
  return repo.getMembers(house.houseId);
});

final membersStreamProvider = StreamProvider<List<HouseMemberEntity>>((ref) {
  final house = ref.watch(currentHouseProvider);
  if (house == null) return Stream.value([]);

  final repo = ref.watch(houseRepositoryProvider);
  return repo.membersStream(house.houseId);
});

// ───── Auth ↔ House Coordinator ─────

/// Watches auth state and keeps the current house in sync automatically.
///
/// Re-runs whenever the auth stream emits (login, logout, account switch),
/// loading the signed-in user's house — or clearing the previous session's
/// house on logout so it never leaks into the next login.
final houseCoordinatorProvider = Provider<void>((ref) {
  final houseRepo = ref.watch(houseRepositoryProvider);

  final user = ref.watch(authStateProvider).value;

  if (user == null || user.uid.isEmpty) {
    houseRepo.clearCurrentHouse();
    return;
  }
  houseRepo.loadUserHouse(user.uid);
});

// ───── Regenerate Invite Code ─────

final regenerateCodeProvider =
    AutoDisposeAsyncNotifierProvider<RegenerateCodeNotifier, String>(
        RegenerateCodeNotifier.new);

class RegenerateCodeNotifier extends AutoDisposeAsyncNotifier<String> {
  @override
  Future<String> build() => Future.value('');

  Future<String?> regenerate(String houseId) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(houseRepositoryProvider);
      final code = await repo.regenerateInviteCode(houseId);
      state = AsyncValue.data(code);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    }
  }
}

// ───── Transfer Treasurer ─────

final transferTreasurerProvider =
    AutoDisposeAsyncNotifierProvider<TransferTreasurerNotifier, void>(
        TransferTreasurerNotifier.new);

class TransferTreasurerNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> transfer(
      String houseId, String fromId, String toId) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(houseRepositoryProvider);
      await repo.transferTreasurer(houseId, fromId, toId);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Leave House Provider ─────

final leaveHouseProvider =
    AutoDisposeAsyncNotifierProvider<LeaveHouseNotifier, void>(
        LeaveHouseNotifier.new);

class LeaveHouseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> leave(
      String houseId, String userId, bool isTreasurer) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(houseRepositoryProvider);
      await repo.leaveHouse(houseId, userId, isTreasurer);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Remove Member ─────

final removeMemberProvider =
    AutoDisposeAsyncNotifierProvider<RemoveMemberNotifier, void>(
        RemoveMemberNotifier.new);

class RemoveMemberNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  static const String permissionOnlyTreasurer =
      'Only the Treasurer can remove a member.';
  static const String cannotRemoveTreasurer =
      'The Treasurer cannot be removed. Transfer ownership first.';

  /// Removes [member] from the current house (soft delete: `isActive` → false).
  ///
  /// Treasurer-only, and the house Treasurer can never be removed (transfer
  /// ownership first). Only the member's house_members record is touched — the
  /// user's Firebase account, their global `users/{uid}` profile, and every
  /// historical expense/transaction/notification are left intact, so they can
  /// join another house later. Returns `null` on success or an error message.
  Future<String?> remove(HouseMemberEntity member) async {
    state = const AsyncValue.loading();
    try {
      final user = ref.read(currentUserProvider);
      if (user == null || user.uid.isEmpty) {
        return 'Not authenticated.';
      }
      final house = ref.read(currentHouseProvider);
      if (house == null) {
        return 'No active house.';
      }
      if (house.treasurerId != user.uid) {
        return permissionOnlyTreasurer;
      }
      if (member.userId == house.treasurerId) {
        return cannotRemoveTreasurer;
      }

      final repo = ref.read(houseRepositoryProvider);
      await repo.removeMember(house.houseId, member.memberId, user.uid);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── No-OP Stub ─────

class _NoOpHouseRepository implements HouseRepository {
  final _notifier = ValueNotifier<HouseEntity?>(null);

  @override
  ValueNotifier<HouseEntity?> get currentHouseNotifier => _notifier;

  @override
  HouseEntity? get currentHouse => null;

  @override
  bool get hasHouse => false;

  @override
  Future<void> loadUserHouse(String userId) async {}

  @override
  Future<void> clearCurrentHouse() async {}

  @override
  Future<List<HouseEntity>> getUserHouses(String userId) async => [];

  @override
  Future<void> switchHouse(String userId, String houseId) async {}

  @override
  Future<HouseEntity> createHouse(String houseName, String treasurerId) =>
      throw FirebaseFailure('Firebase is not configured.');

  @override
  Future<HouseEntity> joinHouse(String inviteCode, String userId) =>
      throw FirebaseFailure('Firebase is not configured.');

  @override
  Future<String> regenerateInviteCode(String houseId) =>
      throw FirebaseFailure('Firebase is not configured.');

  @override
  Future<List<HouseMemberEntity>> getMembers(String houseId) =>
      Future.value([]);

  @override
  Future<HouseMemberEntity?> getMember(String houseId, String userId) =>
      Future.value(null);

  @override
  Future<void> transferTreasurer(
          String houseId, String fromId, String toId) =>
      throw FirebaseFailure('Firebase is not configured.');

  @override
  Future<void> removeMember(
          String houseId, String memberId, String requesterId) =>
      throw FirebaseFailure('Firebase is not configured.');

  @override
  Future<void> leaveHouse(
          String houseId, String userId, bool isTreasurer) =>
      throw FirebaseFailure('Firebase is not configured.');

  @override
  Stream<List<HouseMemberEntity>> membersStream(String houseId) =>
      Stream.value([]);

  @override
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {}
}
