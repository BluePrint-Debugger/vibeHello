import '../models/member_model.dart';
import '../models/room_model.dart';
import '../models/seat_model.dart';
import '../repositories/room_repository.dart';
import 'engines/admin_engine.dart';
import 'engines/event_engine.dart';
import 'engines/lobby_engine.dart';
import 'engines/seat_engine.dart';
import 'engines/voice_engine.dart';

class RoomService {
  RoomService._();

  static final RoomService instance = RoomService._();

  final RoomRepository _repository = RoomRepository.instance;

  //============================================================
  // Engines
  //============================================================

  late final SeatEngine seat = SeatEngine(_repository);

  late final VoiceEngine voice = VoiceEngine(_repository);

  late final AdminEngine admin = AdminEngine(_repository);

  late final LobbyEngine lobby = LobbyEngine(_repository);

  late final EventEngine event = EventEngine(_repository);

  //============================================================
  // Streams
  //============================================================

  Stream<List<SeatModel>> streamSeats(String roomId) {
    return _repository
        .seatStream(roomId)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SeatModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<MemberModel>> streamMembers(String roomId) {
    return _repository
        .memberStream(roomId)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemberModel.fromMap(doc.data()))
              .toList(),
        );
  }

  //============================================================
  // Helpers
  //============================================================

  Future<List<MemberModel>> getMembers(String roomId) async {
    final snapshot = await _repository.getMembers(roomId);

    return snapshot.docs.map((doc) => MemberModel.fromMap(doc.data())).toList();
  }

  Future<SeatModel?> getSeat(String roomId, int seatNumber) async {
    final doc = await _repository.getSeat(roomId, seatNumber);

    if (!doc.exists) {
      return null;
    }

    return SeatModel.fromMap(doc.data()!);
  }

  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final doc = await _repository.getRoom(roomId);

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  //============================================================
  // Room List
  //============================================================

  /// Live list of every room, newest first. Used by the room browser.
  Stream<List<RoomModel>> getRooms() {
    return _repository.roomsStream().map(
      (snapshot) => snapshot.docs
          .map((doc) => RoomModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Creates a new room and returns its id.
  Future<String> createRoom({
    required String title,
    required String createdBy,
    required bool isPrivate,
    String? password,
    required String roomType,
    int maxSeats = 8,
  }) async {
    final ref = await _repository.createRoom({
      'title': title,
      'createdBy': createdBy,
      'usersCount': 0,
      'isPrivate': isPrivate,
      'password': password,
      'roomType': roomType,
      'hostId': createdBy,
      'maxSeats': maxSeats,
      'chatEnabled': true,
      'lobbyEnabled': true,
    });
    return ref.id;
  }

  //============================================================
  // Room
  //============================================================

  Future<void> updateRoom(String roomId, Map<String, dynamic> data) {
    return _repository.updateRoom(roomId, data);
  }
}
