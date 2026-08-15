import '../repositories/room_repository.dart';

class LobbyService {
  LobbyService._();

  static final LobbyService instance = LobbyService._();

  final RoomRepository _repository = RoomRepository.instance;

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

  Future<void> leaveLobby({
    required String roomId,
    required String uid,
  }) async {
    await _repository.deleteLobbyUser(roomId, uid);

    await _repository.addEvent(roomId, {"type": "lobby_left", "uid": uid});
  }

  Future<void> acceptUser({
    required String roomId,
    required String uid,
  }) async {
    await _repository.deleteLobbyUser(roomId, uid);

    await _repository.addEvent(roomId, {"type": "lobby_accepted", "uid": uid});
  }

  Future<void> rejectUser({
    required String roomId,
    required String uid,
  }) async {
    await _repository.deleteLobbyUser(roomId, uid);

    await _repository.addEvent(roomId, {"type": "lobby_rejected", "uid": uid});
  }

  Future<void> inviteUser({
    required String roomId,
    required String uid,
  }) async {
    await _repository.updateLobbyUser(roomId, uid, {"invited": true});

    await _repository.addEvent(roomId, {"type": "stage_invite", "uid": uid});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> lobbyStream(String roomId) {
    return _repository.lobbyStream(roomId);
  }
}