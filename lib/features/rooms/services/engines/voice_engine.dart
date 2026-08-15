import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/room_repository.dart';

class VoiceEngine {
  VoiceEngine(this._repository);

  final RoomRepository _repository;

  //============================================================
  // Toggle Mic
  //============================================================

  Future<void> toggleMic({
    required String roomId,
    required String uid,
    required int seatNumber,
    required bool micOn,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      final seatSnap = await tx.get(seatRef);

      if (!seatSnap.exists) {
        throw Exception("Seat not found.");
      }

      final seat = seatSnap.data()!;

      if (seat["userId"] != uid) {
        throw Exception("Seat ownership mismatch.");
      }

      tx.update(seatRef, {"micOn": micOn});

      tx.update(memberRef, {"micOn": micOn});
    });
  }

  //============================================================
  // Update Speaking State
  //============================================================

  Future<void> setSpeaking({
    required String roomId,
    required String uid,
    required int seatNumber,
    required bool speaking,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      final seatSnap = await tx.get(seatRef);

      if (!seatSnap.exists) {
        throw Exception("Seat not found.");
      }

      final seat = seatSnap.data()!;

      if (seat["userId"] != uid) {
        throw Exception("Seat ownership mismatch.");
      }

      tx.update(seatRef, {"isSpeaking": speaking});

      tx.update(memberRef, {"isSpeaking": speaking});
    });
  }

  //============================================================
  // Mute By Admin
  //============================================================

  Future<void> muteByAdmin({
    required String roomId,
    required String uid,
    required int seatNumber,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      tx.update(seatRef, {"micOn": false, "mutedByAdmin": true});

      tx.update(memberRef, {"micOn": false, "mutedByAdmin": true});
    });
  }

  //============================================================
  // Unmute By Admin
  //============================================================

  Future<void> unMuteByAdmin({
    required String roomId,
    required String uid,
    required int seatNumber,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      tx.update(seatRef, {"mutedByAdmin": false});

      tx.update(memberRef, {"mutedByAdmin": false});
    });
  }

  //============================================================
  // Force Mic Off
  //============================================================

  Future<void> forceMicOff({
    required String roomId,
    required String uid,
    required int seatNumber,
  }) async {
    await _repository.runTransaction((tx) async {
      final seatRef = _repository.seatRef(roomId, seatNumber);
      final memberRef = _repository.memberRef(roomId, uid);

      tx.update(seatRef, {"micOn": false, "isSpeaking": false});

      tx.update(memberRef, {"micOn": false, "isSpeaking": false});
    });
  }

  //============================================================
  // Reset Speaking
  //============================================================

  Future<void> resetSpeaking({required String roomId}) async {
    final members = await _repository.getMembers(roomId);

    final batch = _repository.batch();

    for (final member in members.docs) {
      final data = member.data();

      final seatNumber = data["seatNumber"] ?? -1;

      if (seatNumber == -1) {
        continue;
      }

      batch.update(_repository.seatRef(roomId, seatNumber), {
        "isSpeaking": false,
      });

      batch.update(_repository.memberRef(roomId, member.id), {
        "isSpeaking": false,
      });
    }

    await batch.commit();
  }
}
