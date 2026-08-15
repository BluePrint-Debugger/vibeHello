import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/member_model.dart';
import '../../models/room_role.dart';
import '../../models/seat_model.dart';
import '../../repositories/room_repository.dart';

class SeatEngine {
  SeatEngine(this._repository);

  final RoomRepository _repository;

  //============================================================
  // Join Seat
  //============================================================

  Future<void> joinSeat({
    required String roomId,
    required int seatNumber,
    required String uid,
    required String name,
    required String photo,
    RoomRole role = RoomRole.speaker,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      final seatSnap = await tx.get(seatRef);

      if (!seatSnap.exists) {
        throw Exception("Seat not found");
      }

      final seat = SeatModel.fromMap(seatSnap.data()!);

      if (!seat.isOpen) {
        throw Exception("Seat is not available");
      }

      final memberSnap = await tx.get(memberRef);

      if (memberSnap.exists) {
        final member = MemberModel.fromMap(memberSnap.data()!);

        if (member.seatNumber != -1) {
          throw Exception("User already occupies a seat");
        }
      }

      tx.set(seatRef, {
        "seatNumber": seatNumber,
        "state": SeatState.occupied.name,
        "userId": uid,
        "userName": name,
        "photo": photo,
        "role": role.value,
        "micOn": true,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "invited": false,
        "joinedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(memberRef, {
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
      }, SetOptions(merge: true));
    });
  }

  //============================================================
  // Leave Seat
  //============================================================

  Future<void> leaveSeat({
    required String roomId,
    required int seatNumber,
    required String uid,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      final seatSnap = await tx.get(seatRef);

      if (!seatSnap.exists) {
        throw Exception("Seat not found");
      }

      final seat = SeatModel.fromMap(seatSnap.data()!);

      if (seat.userId != uid) {
        throw Exception("Seat owner mismatch");
      }

      tx.set(seatRef, {
        "seatNumber": seatNumber,
        "state": SeatState.open.name,
        "userId": null,
        "userName": null,
        "photo": null,
        "role": RoomRole.listener.value,
        "micOn": false,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "invited": false,
        "joinedAt": null,
      }, SetOptions(merge: true));

      tx.update(memberRef, {
        "seatNumber": -1,
        "role": RoomRole.listener.value,
        "micOn": false,
        "isSpeaking": false,
      });
    });
  }

  //============================================================
  // Switch Seat
  //============================================================

  Future<void> switchSeat({
    required String roomId,
    required int fromSeat,
    required int toSeat,
    required MemberModel member,
  }) async {
    await _repository.runTransaction((tx) async {
      final fromRef = _repository.seatRef(roomId, fromSeat);
      final toRef = _repository.seatRef(roomId, toSeat);
      final memberRef = _repository.memberRef(roomId, member.uid);

      final toSnap = await tx.get(toRef);

      if (!toSnap.exists) {
        throw Exception("Seat not found");
      }

      final destination = SeatModel.fromMap(toSnap.data()!);

      if (!destination.isOpen) {
        throw Exception("Destination seat unavailable");
      }

      tx.set(fromRef, {
        "seatNumber": fromSeat,
        "state": SeatState.open.name,
        "userId": null,
        "userName": null,
        "photo": null,
        "role": RoomRole.listener.value,
        "micOn": false,
        "isSpeaking": false,
        "mutedByAdmin": false,
        "invited": false,
        "joinedAt": null,
      }, SetOptions(merge: true));

      tx.set(toRef, {
        "seatNumber": toSeat,
        "state": SeatState.occupied.name,
        "userId": member.uid,
        "userName": member.name,
        "photo": member.photo,
        "role": member.role.value,
        "micOn": member.micOn,
        "isSpeaking": member.isSpeaking,
        "mutedByAdmin": member.mutedByAdmin,
        "invited": false,
        "joinedAt": Timestamp.fromDate(member.joinedAt),
      }, SetOptions(merge: true));

      tx.update(memberRef, {"seatNumber": toSeat});
    });
  }

  //============================================================
  // Helpers
  //============================================================

  Future<bool> isSeatAvailable(String roomId, int seatNumber) async {
    final seat = await _repository.getSeat(roomId, seatNumber);

    if (!seat.exists) {
      return false;
    }

    return SeatModel.fromMap(seat.data()!).isOpen;
  }

  Future<int?> getUserSeat(String roomId, String uid) async {
    final member = await _repository.getMember(roomId, uid);

    if (!member.exists) {
      return null;
    }

    return MemberModel.fromMap(member.data()!).seatNumber;
  }
}
