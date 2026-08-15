import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/room_repository.dart';

class LobbyEngine {
  LobbyEngine(this._repository);

  final RoomRepository _repository;

  //============================================================
  // JOIN LOBBY
  //============================================================

  Future<void> joinLobby({
    required String roomId,
    required String uid,
    required String name,
    required String photo,
  }) async {
    await _repository.updateLobbyUser(roomId, uid, {
      "uid": uid,
      "name": name,
      "photo": photo,
      "requestedAt": FieldValue.serverTimestamp(),
    });

    await _repository.addEvent(roomId, {"type": "lobby_joined", "uid": uid});
  }

  //============================================================
  // LEAVE LOBBY
  //============================================================

  Future<void> leaveLobby({required String roomId, required String uid}) async {
    await _repository.deleteLobbyUser(roomId, uid);

    await _repository.addEvent(roomId, {"type": "lobby_left", "uid": uid});
  }

  //============================================================
  // ACCEPT USER
  //============================================================

  Future<void> acceptUser({required String roomId, required String uid}) async {
    await _repository.deleteLobbyUser(roomId, uid);

    await _repository.addEvent(roomId, {"type": "lobby_accepted", "uid": uid});
  }

  //============================================================
  // REJECT USER
  //============================================================

  Future<void> rejectUser({required String roomId, required String uid}) async {
    await _repository.deleteLobbyUser(roomId, uid);

    await _repository.addEvent(roomId, {"type": "lobby_rejected", "uid": uid});
  }

  //============================================================
  // INVITE USER
  //============================================================

  Future<void> inviteUser({required String roomId, required String uid}) async {
    await _repository.updateLobbyUser(roomId, uid, {"invited": true});

    await _repository.addEvent(roomId, {"type": "stage_invite", "uid": uid});
  }
}
