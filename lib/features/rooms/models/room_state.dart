import 'lobby_member_model.dart';
import 'member_model.dart';
import 'room_model.dart';
import 'seat_model.dart';

class RoomState {
  final RoomModel room;

  final List<SeatModel> seats;

  final List<MemberModel> members;

  final List<LobbyMemberModel> lobby;

  final List<String> admins;

  final bool isCurrentUserAdmin;

  final bool isHost;

  const RoomState({
    required this.room,
    required this.seats,
    required this.members,
    required this.lobby,
    required this.admins,
    required this.isCurrentUserAdmin,
    required this.isHost,
  });

  RoomState copyWith({
    RoomModel? room,
    List<SeatModel>? seats,
    List<MemberModel>? members,
    List<LobbyMemberModel>? lobby,
    List<String>? admins,
    bool? isCurrentUserAdmin,
    bool? isHost,
  }) {
    return RoomState(
      room: room ?? this.room,
      seats: seats ?? this.seats,
      members: members ?? this.members,
      lobby: lobby ?? this.lobby,
      admins: admins ?? this.admins,
      isCurrentUserAdmin: isCurrentUserAdmin ?? this.isCurrentUserAdmin,
      isHost: isHost ?? this.isHost,
    );
  }
}
