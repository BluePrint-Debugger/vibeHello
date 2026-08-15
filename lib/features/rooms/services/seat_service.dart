import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/room_role.dart';
import '../models/seat_model.dart';
import '../repositories/room_repository.dart';

class SeatService {
  SeatService();

  final RoomRepository _repository = RoomRepository.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SeatModel>> getSeats(String roomId) {
    return _repository
        .seats(roomId)
        .orderBy('seatNumber')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((e) => SeatModel.fromMap(e.data())).toList(),
        );
  }

  Future<void> joinSeat({
    required String roomId,
    required int seatNumber,
    required String uid,
    required String name,
    required String photo,
    required RoomRole role,
  }) async {
    final seatRef = _repository.seats(roomId).doc("seat_$seatNumber");

    final memberRef = _repository.members(roomId).doc(uid);

    final roomRef = _repository.room(roomId);

    await _firestore.runTransaction((transaction) async {
      final seat = await transaction.get(seatRef);

      if (!seat.exists) {
        throw Exception("Seat not found");
      }

      final seatData = seat.data()!;

      if (seatData["state"] == "locked") {
        throw Exception("Seat is locked");
      }

      if (seatData["state"] == "occupied") {
        throw Exception("Seat already occupied");
      }

      transaction.update(seatRef, {
        "state": "occupied",
        "userId": uid,
        "userName": name,
        "photo": photo,
        "role": role.value,
        "micOn": true,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "joinedAt": FieldValue.serverTimestamp(),
      });

      transaction.set(memberRef, {
        "uid": uid,
        "name": name,
        "photo": photo,
        "role": role.value,
        "seatNumber": seatNumber,
        "micOn": true,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "chatBlocked": false,
        "joinedAt": FieldValue.serverTimestamp(),
      });

      transaction.update(roomRef, {"usersCount": FieldValue.increment(1)});
    });
  }

  Future<void> leaveSeat({
    required String roomId,
    required int seatNumber,
    required String uid,
  }) async {
    final seatRef = _repository.seats(roomId).doc("seat_$seatNumber");

    final memberRef = _repository.members(roomId).doc(uid);

    final roomRef = _repository.room(roomId);

    await _firestore.runTransaction((transaction) async {
      transaction.update(seatRef, {
        "state": "open",
        "userId": null,
        "userName": null,
        "photo": null,
        "role": RoomRole.listener.value,
        "micOn": false,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "joinedAt": null,
      });

      transaction.delete(memberRef);

      transaction.update(roomRef, {"usersCount": FieldValue.increment(-1)});
    });
  }

  Future<void> lockSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    await _repository.seats(roomId).doc("seat_$seatNumber").update({
      "state": "locked",
    });
  }

  Future<void> unlockSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    await _repository.seats(roomId).doc("seat_$seatNumber").update({
      "state": "open",
    });
  }

  Future<void> updateMic({
    required String roomId,
    required int seatNumber,
    required bool micOn,
    required String uid,
  }) async {
    await Future.wait([
      _repository.seats(roomId).doc("seat_$seatNumber").update({
        "micOn": micOn,
      }),
      _repository.members(roomId).doc(uid).update({"micOn": micOn}),
    ]);
  }

  Future<void> updateSpeaking({
    required String roomId,
    required int seatNumber,
    required bool speaking,
    required String uid,
  }) async {
    await Future.wait([
      _repository.seats(roomId).doc("seat_$seatNumber").update({
        "isSpeaking": speaking,
      }),
      _repository.members(roomId).doc(uid).update({"isSpeaking": speaking}),
    ]);
  }
}
