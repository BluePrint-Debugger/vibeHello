import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/seat_model.dart';
import '../repositories/room_repository.dart';

class SeatService {
  final RoomRepository _repository = RoomRepository();

  Stream<List<SeatModel>> getSeats(String roomId) {
    return _repository
        .seats(roomId)
        .orderBy('seatNumber')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeatModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> occupySeat({
    required String roomId,
    required int seatNumber,
    required String uid,
    required String userName,
    required String? photo,
    required String role,
  }) async {
    await _repository.seats(roomId).doc("seat_$seatNumber").set({
      "seatNumber": seatNumber,
      "state": "occupied",
      "userId": uid,
      "userName": userName,
      "photo": photo,
      "micOn": true,
      "isSpeaking": false,
      "role": role,
      "joinedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> leaveSeat({
    required String roomId,
    required int seatNumber,
  }) async {
    await _repository.seats(roomId).doc("seat_$seatNumber").set({
      "seatNumber": seatNumber,
      "state": "open",
      "userId": null,
      "userName": null,
      "photo": null,
      "micOn": false,
      "isSpeaking": false,
      "role": "listener",
      "joinedAt": null,
    }, SetOptions(merge: true));
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
  }) async {
    await _repository.seats(roomId).doc("seat_$seatNumber").update({
      "micOn": micOn,
    });
  }

  Future<void> updateSpeaking({
    required String roomId,
    required int seatNumber,
    required bool speaking,
  }) async {
    await _repository.seats(roomId).doc("seat_$seatNumber").update({
      "isSpeaking": speaking,
    });
  }
}
