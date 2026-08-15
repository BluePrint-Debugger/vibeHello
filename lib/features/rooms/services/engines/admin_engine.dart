import '../../models/room_role.dart';
import '../../models/seat_model.dart';
import '../../repositories/room_repository.dart';

class AdminEngine {
  AdminEngine(this._repository);

  final RoomRepository _repository;

  //============================================================
  // Lock Seat
  //============================================================

  Future<void> lockSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    final seat = await _repository.getSeat(roomId, seatNumber);

    if (!seat.exists) {
      throw Exception("Seat not found.");
    }

    final seatModel = SeatModel.fromMap(seat.data()!);

    if (seatModel.isOccupied) {
      throw Exception("Cannot lock an occupied seat.");
    }

    await _repository.updateSeat(roomId, seatNumber, {
      "state": SeatState.locked.name,
    });
  }

  //============================================================
  // Unlock Seat
  //============================================================

  Future<void> unlockSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    await _repository.updateSeat(roomId, seatNumber, {
      "state": SeatState.open.name,
    });
  }

  //============================================================
  // Reserve Seat
  //============================================================

  Future<void> reserveSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    final seat = await _repository.getSeat(roomId, seatNumber);

    if (!seat.exists) {
      throw Exception("Seat not found.");
    }

    final model = SeatModel.fromMap(seat.data()!);

    if (model.isOccupied) {
      throw Exception("Cannot reserve occupied seat.");
    }

    await _repository.updateSeat(roomId, seatNumber, {
      "state": SeatState.reserved.name,
    });
  }

  //============================================================
  // Open Reserved Seat
  //============================================================

  Future<void> openSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    await _repository.updateSeat(roomId, seatNumber, {
      "state": SeatState.open.name,
    });
  }

  //============================================================
  // Promote Member
  //============================================================

  Future<void> promoteMember({
    required String roomId,
    required String uid,
    required RoomRole role,
  }) async {
    final member = await _repository.getMember(roomId, uid);

    if (!member.exists) {
      throw Exception("Member not found.");
    }

    final data = member.data()!;
    final seatNumber = data["seatNumber"] ?? -1;

    await _repository.updateMember(roomId, uid, {"role": role.value});

    if (seatNumber != -1) {
      await _repository.updateSeat(roomId, seatNumber, {"role": role.value});
    }
  }

  //============================================================
  // Demote To Listener
  //============================================================

  Future<void> demoteToListener({
    required String roomId,
    required String uid,
  }) async {
    final member = await _repository.getMember(roomId, uid);

    if (!member.exists) {
      throw Exception("Member not found.");
    }

    final data = member.data()!;
    final seatNumber = data["seatNumber"] ?? -1;

    await _repository.updateMember(roomId, uid, {
      "role": RoomRole.listener.value,
    });

    if (seatNumber != -1) {
      await _repository.updateSeat(roomId, seatNumber, {
        "role": RoomRole.listener.value,
      });
    }
  }

  //============================================================
  // Block Chat
  //============================================================

  Future<void> blockChat({required String roomId, required String uid}) async {
    await _repository.updateMember(roomId, uid, {"chatBlocked": true});
  }

  //============================================================
  // Unblock Chat
  //============================================================

  Future<void> unblockChat({
    required String roomId,
    required String uid,
  }) async {
    await _repository.updateMember(roomId, uid, {"chatBlocked": false});
  }

  //============================================================
  // Remove From Stage
  //============================================================

  Future<void> removeFromStage({
    required String roomId,
    required String uid,
  }) async {
    final member = await _repository.getMember(roomId, uid);

    if (!member.exists) {
      throw Exception("Member not found.");
    }

    final data = member.data()!;
    final seatNumber = data["seatNumber"] ?? -1;

    if (seatNumber == -1) {
      return;
    }

    await _repository.runTransaction((tx) async {
      tx.update(_repository.seatRef(roomId, seatNumber), {
        "state": SeatState.open.name,
        "userId": null,
        "userName": null,
        "photo": null,
        "role": RoomRole.listener.value,
        "micOn": false,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "joinedAt": null,
      });

      tx.update(_repository.memberRef(roomId, uid), {
        "seatNumber": -1,
        "role": RoomRole.listener.value,
        "micOn": false,
        "isSpeaking": false,
      });
    });
  }

  //============================================================
  // Transfer Host
  //============================================================

  Future<void> transferHost({
    required String roomId,
    required String oldHostUid,
    required String newHostUid,
  }) async {
    await _repository.runTransaction((tx) async {
      tx.update(_repository.memberRef(roomId, oldHostUid), {
        "role": RoomRole.admin.value,
      });

      tx.update(_repository.memberRef(roomId, newHostUid), {
        "role": RoomRole.host.value,
      });

      tx.update(_repository.room(roomId), {"hostId": newHostUid});
    });
  }
}
