import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/house_remote_datasource.dart';
import '../../data/repositories/house_repository_impl.dart';
import '../../domain/entities/house_entity.dart';
import '../../domain/entities/house_member_entity.dart';
import '../../domain/repositories/house_repository.dart';

/// Stable, machine-readable codes for the house-management guards whose message
/// reaches the screen.
///
/// ## Why this exists
///
/// A provider has no `BuildContext`, so it cannot localize its own text, and
/// `AppLocalizations` must never be looked up from here. Instead of returning
/// English prose that would be shown verbatim to a Malay reader, each notifier
/// returns one of the codes below and the **page** that displays it resolves
/// the code to a localized message via [messageFor]. The decision "which error
/// is this" is therefore keyed on a stable code, never on translated text —
/// the same contract `AuthErrorCodes` established for the sign-in flow.
///
/// A value that is *not* one of these codes is a message that came from a
/// [Failure] raised in the data layer; [messageFor] passes it through unchanged,
/// exactly as it was displayed before.
class HouseErrorCodes {
  const HouseErrorCodes._();

  /// The action ran without a signed-in user.
  static const String notAuthenticated = 'house/not-authenticated';

  /// The action ran with no active house selected.
  static const String noActiveHouse = 'house/no-active-house';

  /// A non-Treasurer attempted a Treasurer-only action.
  static const String onlyTreasurerRemove = 'house/only-treasurer-remove';

  /// The house Treasurer can never be removed — ownership must be transferred.
  static const String cannotRemoveTreasurer = 'house/cannot-remove-treasurer';

  /// Fallback for an unclassified failure.
  static const String unexpected = 'house/unexpected';

  /// Firebase was never initialised, so no house call can run.
  static const String firebaseNotConfigured = 'house/firebase-not-configured';

  /// Every code [messageFor] can turn into a localized message.
  ///
  /// [fromFailure] only ever returns a code from this set, which is what keeps
  /// an unknown third-party code from reaching the screen as a raw slug.
  static const Set<String> _localized = {
    notAuthenticated,
    noActiveHouse,
    onlyTreasurerRemove,
    cannotRemoveTreasurer,
    unexpected,
    firebaseNotConfigured,
    // Raised by the Cloud Function / datasource and described by the shared
    // failure vocabulary the other features use, so the join flow reads the
    // same way a failed expense action does.
    FailureCodes.houseAlreadyMember,
    FailureCodes.houseInvalidCode,
    FailureCodes.permission,
    FailureCodes.network,
  };

  /// What a notifier should return for a data-layer [Failure]: the failure's
  /// stable [Failure.code] when this layer knows how to localize it, otherwise
  /// the failure's own message — which is what was displayed before.
  static String fromFailure(Failure failure) {
    final code = failure.code;
    if (code != null && _localized.contains(code)) return code;
    return failure.message;
  }

  /// The message to show for a value returned by one of the house notifiers.
  ///
  /// Call this from the page that displays the error, passing the active
  /// [l10n] — that is what keeps the text following a runtime language switch.
  static String messageFor(String error, AppLocalizations l10n) {
    switch (error) {
      case notAuthenticated:
        return l10n.houseErrorNotAuthenticated;
      case noActiveHouse:
        return l10n.houseErrorNoActiveHouse;
      case onlyTreasurerRemove:
        return l10n.houseErrorOnlyTreasurerRemove;
      case cannotRemoveTreasurer:
        return l10n.houseErrorCannotRemoveTreasurer;
      case unexpected:
        return l10n.houseErrorUnexpected;
      case firebaseNotConfigured:
        return l10n.houseErrorFirebaseNotConfigured;
      default:
        // Anything else is either a code the shared failure vocabulary knows or
        // text the data layer already wrote for display; [forError] resolves the
        // first and passes the second through untouched, so no code slug can
        // reach the user and no English prose is invented here.
        return FailureMessages.forError(error, l10n);
    }
  }
}

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

/// The signed-in user's current house — LIVE.
///
/// Previously this read the repository once, so everything that depends on it
/// (Treasurer checks, members, dashboard, bills…) kept the house as it was when
/// first read: a Treasurer transfer, a switch of house or a rename only showed
/// after a page reload. It now re-evaluates whenever the repository's current
/// house changes in a way the app shows ([houseDetailsDiffer]) — including
/// changes made on another device, which the repository follows live.
final currentHouseProvider = Provider<HouseEntity?>((ref) {
  final notifier = ref.watch(houseRepositoryProvider).currentHouseNotifier;
  final house = notifier.value;
  void onChange() {
    if (houseDetailsDiffer(house, notifier.value)) ref.invalidateSelf();
    // (HouseEntity.== compares these same details, so the rebuilt value is
    // "not equal" and dependents are notified.)
  }

  notifier.addListener(onChange);
  ref.onDispose(() => notifier.removeListener(onChange));
  return house;
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
      if (user == null) return HouseErrorCodes.notAuthenticated;

      final repo = ref.read(houseRepositoryProvider);
      await repo.switchHouse(user.uid, houseId);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.fromFailure(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.unexpected;
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
      return HouseErrorCodes.fromFailure(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.unexpected;
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
      return HouseErrorCodes.fromFailure(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.unexpected;
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

/// Stream of ALL house member records — active AND inactive former members —
/// one display record per user (active membership wins).
///
/// Read-only name source for HISTORICAL records: History, Expense/Transaction
/// Details and the Expense List resolve a UID left on an old expense or
/// transaction to a name. Using [membersStreamProvider] there would blank a
/// former member's history ("Unknown Member") the moment they are removed,
/// because it filters to active members only. This provider exists ONLY for
/// name resolution — never for the current roster, deposit payer choices,
/// role checks, or Treasurer tracing, which must keep using
/// [membersStreamProvider].
final allMembersStreamProvider = StreamProvider<List<HouseMemberEntity>>((ref) {
  final house = ref.watch(currentHouseProvider);
  if (house == null) return Stream.value([]);

  final repo = ref.watch(houseRepositoryProvider);
  return repo.allMembersStream(house.houseId);
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
      return HouseErrorCodes.fromFailure(e);
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
      return HouseErrorCodes.fromFailure(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.unexpected;
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
      return HouseErrorCodes.fromFailure(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.unexpected;
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

  /// Public names for the two Treasurer-only guards. Their value is now the
  /// stable code from [HouseErrorCodes] rather than English prose, so the page
  /// can resolve it to the active locale — see [HouseErrorCodes.messageFor].
  static const String permissionOnlyTreasurer =
      HouseErrorCodes.onlyTreasurerRemove;
  static const String cannotRemoveTreasurer =
      HouseErrorCodes.cannotRemoveTreasurer;

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
        return HouseErrorCodes.notAuthenticated;
      }
      final house = ref.read(currentHouseProvider);
      if (house == null) {
        return HouseErrorCodes.noActiveHouse;
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
      return HouseErrorCodes.fromFailure(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return HouseErrorCodes.unexpected;
    }
  }
}

// ───── No-OP Stub ─────

class _NoOpHouseRepository implements HouseRepository {
  final _notifier = ValueNotifier<HouseEntity?>(null);

  /// Nothing to resolve without Firebase — starting `true` keeps the router
  /// from holding anyone on the splash waiting for a lookup that cannot run.
  final _resolvedNotifier = ValueNotifier<bool>(true);

  @override
  ValueNotifier<HouseEntity?> get currentHouseNotifier => _notifier;

  @override
  ValueNotifier<bool> get houseResolvedNotifier => _resolvedNotifier;

  @override
  bool get isHouseResolved => true;

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
      throw FirebaseFailure(
        'Firebase is not configured.',
        code: HouseErrorCodes.firebaseNotConfigured,
      );

  @override
  Future<HouseEntity> joinHouse(String inviteCode, String userId) =>
      throw FirebaseFailure(
        'Firebase is not configured.',
        code: HouseErrorCodes.firebaseNotConfigured,
      );

  @override
  Future<String> regenerateInviteCode(String houseId) =>
      throw FirebaseFailure(
        'Firebase is not configured.',
        code: HouseErrorCodes.firebaseNotConfigured,
      );

  @override
  Future<List<HouseMemberEntity>> getMembers(String houseId) =>
      Future.value([]);

  @override
  Future<HouseMemberEntity?> getMember(String houseId, String userId) =>
      Future.value(null);

  @override
  Future<void> transferTreasurer(
          String houseId, String fromId, String toId) =>
      throw FirebaseFailure(
        'Firebase is not configured.',
        code: HouseErrorCodes.firebaseNotConfigured,
      );

  @override
  Future<void> removeMember(
          String houseId, String memberId, String requesterId) =>
      throw FirebaseFailure(
        'Firebase is not configured.',
        code: HouseErrorCodes.firebaseNotConfigured,
      );

  @override
  Future<void> leaveHouse(
          String houseId, String userId, bool isTreasurer) =>
      throw FirebaseFailure(
        'Firebase is not configured.',
        code: HouseErrorCodes.firebaseNotConfigured,
      );

  @override
  Stream<List<HouseMemberEntity>> membersStream(String houseId) =>
      Stream.value([]);

  @override
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId) =>
      Stream.value([]);

  @override
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {}
}
