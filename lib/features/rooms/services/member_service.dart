import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member_model.dart';
import '../models/room_role.dart';
import '../repositories/room_repository.dart';

class MemberService {
  final RoomRepository _repository = RoomRepository.instance;

  Stream<List<MemberModel>> members(String roomId) {
    return _repository
        .members(roomId)
        .snapshots()
        .map(
          (e) => e.docs.map((doc) => MemberModel.fromMap(doc.data())).toList(),
        );
  }

  Future<void> addMember({
    required String roomId,
    required String uid,
    required String name,
    required String photo,
    required RoomRole role,
    required int seatNumber,
  }) async {
    await _repository.members(roomId).doc(uid).set({
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
  }

  Future<void> removeMember(String roomId, String uid) async {
    await _repository.members(roomId).doc(uid).delete();
  }

  Future<void> updateSeat(String roomId, String uid, int seat) async {
    await _repository.members(roomId).doc(uid).update({"seatNumber": seat});
  }

  Future<void> updateRole(String roomId, String uid, RoomRole role) async {
    await _repository.members(roomId).doc(uid).update({"role": role.value});
  }

  Future<void> updateMic(String roomId, String uid, bool mic) async {
    await _repository.members(roomId).doc(uid).update({"micOn": mic});
  }

  Future<void> updateSpeaking(String roomId, String uid, bool speaking) async {
    await _repository.members(roomId).doc(uid).update({"isSpeaking": speaking});
  }

  Future<void> mute(String roomId, String uid, bool muted) async {
    await _repository.members(roomId).doc(uid).update({"mutedByAdmin": muted});
  }
}
