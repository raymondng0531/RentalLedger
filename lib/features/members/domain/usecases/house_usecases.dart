import '../entities/house_entity.dart';
import '../entities/house_member_entity.dart';
import '../repositories/house_repository.dart';

// ───── Create House ─────

class CreateHouseUseCase {
  const CreateHouseUseCase(this._repository);
  final HouseRepository _repository;

  Future<HouseEntity> call(String houseName, String treasurerId) {
    return _repository.createHouse(houseName, treasurerId);
  }
}

// ───── Join House ─────

class JoinHouseUseCase {
  const JoinHouseUseCase(this._repository);
  final HouseRepository _repository;

  Future<HouseEntity> call(String inviteCode, String userId) {
    return _repository.joinHouse(inviteCode, userId);
  }
}

// ───── Get Members ─────

class GetMembersUseCase {
  const GetMembersUseCase(this._repository);
  final HouseRepository _repository;

  Future<List<HouseMemberEntity>> call(String houseId) {
    return _repository.getMembers(houseId);
  }
}

// ───── Transfer Treasurer ─────

class TransferTreasurerUseCase {
  const TransferTreasurerUseCase(this._repository);
  final HouseRepository _repository;

  Future<void> call(
      String houseId, String fromId, String toId) {
    return _repository.transferTreasurer(houseId, fromId, toId);
  }
}

// ───── Leave House ─────

class LeaveHouseUseCase {
  const LeaveHouseUseCase(this._repository);
  final HouseRepository _repository;

  Future<void> call(String houseId, String userId, bool isTreasurer) {
    return _repository.leaveHouse(houseId, userId, isTreasurer);
  }
}

// ───── Remove Member ─────

class RemoveMemberUseCase {
  const RemoveMemberUseCase(this._repository);
  final HouseRepository _repository;

  Future<void> call(String houseId, String memberId, String requesterId) {
    return _repository.removeMember(houseId, memberId, requesterId);
  }
}
