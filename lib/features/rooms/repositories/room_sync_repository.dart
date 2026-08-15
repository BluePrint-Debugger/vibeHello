import 'package:cloud_firestore/cloud_firestore.dart';

import 'room_repository.dart';

class RoomSyncRepository {
  RoomSyncRepository(this._repository);

  final RoomRepository _repository;

  // ==========================================================
  // UPDATE SEAT + MEMBER
  // ==========================================================

  Future<void> updateSeatAndMember({
    required String roomId,
    required int seatNumber,
    required String uid,
    Map<String, dynamic>? seatData,
    Map<String, dynamic>? memberData,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    if (seatData != null) {
      batch.set(
        _repository.seats(roomId).doc("seat_$seatNumber"),
        seatData,
        SetOptions(merge: true),
      );
    }

    if (memberData != null) {
      batch.set(
        _repository.members(roomId).doc(uid),
        memberData,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  // ==========================================================
  // CLEAR SEAT + REMOVE MEMBER
  // ==========================================================

  Future<void> clearSeatAndMember({
    required String roomId,
    required int seatNumber,
    required String uid,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.set(_repository.seats(roomId).doc("seat_$seatNumber"), {
      "state": "open",
      "userId": null,
      "userName": null,
      "photo": null,
      "role": "listener",
      "micOn": false,
      "isSpeaking": false,
      "mutedByAdmin": false,
      "joinedAt": null,
    }, SetOptions(merge: true));

    batch.delete(_repository.members(roomId).doc(uid));

    await batch.commit();
  }

  // ==========================================================
  // UPDATE MIC STATE
  // ==========================================================

  Future<void> updateMicState({
    required String roomId,
    required int seatNumber,
    required String uid,
    required bool micOn,
    bool? mutedByAdmin,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    final data = {
      "micOn": micOn,
      "mutedByAdmin": ?mutedByAdmin,
    };

    batch.set(
      _repository.seats(roomId).doc("seat_$seatNumber"),
      data,
      SetOptions(merge: true),
    );

    batch.set(
      _repository.members(roomId).doc(uid),
      data,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ==========================================================
  // UPDATE SPEAKING STATE
  // ==========================================================

  Future<void> updateSpeakingState({
    required String roomId,
    required int seatNumber,
    required String uid,
    required bool speaking,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.set(_repository.seats(roomId).doc("seat_$seatNumber"), {
      "isSpeaking": speaking,
    }, SetOptions(merge: true));

    batch.set(_repository.members(roomId).doc(uid), {
      "isSpeaking": speaking,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ==========================================================
  // UPDATE ROLE
  // ==========================================================

  Future<void> updateRole({
    required String roomId,
    required String uid,
    required String role,
  }) async {
    await _repository.updateMember(roomId, uid, {"role": role});
  }

  // ==========================================================
  // UPDATE CHAT BLOCK
  // ==========================================================

  Future<void> updateChatBlock({
    required String roomId,
    required String uid,
    required bool blocked,
  }) async {
    await _repository.updateMember(roomId, uid, {"chatBlocked": blocked});
  }

  // ==========================================================
  // UPDATE SEAT STATE
  // ==========================================================

  Future<void> updateSeatState({
    required String roomId,
    required int seatNumber,
    required String state,
  }) async {
    await _repository.updateSeat(roomId, seatNumber, {"state": state});
  }

  // ==========================================================
  // TRANSFER HOST
  // ==========================================================

  Future<void> transferHost({
    required String roomId,
    required String newHostUid,
  }) async {
    await _repository.updateRoom(roomId, {"hostId": newHostUid});
  }
}
