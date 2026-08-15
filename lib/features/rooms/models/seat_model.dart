import 'package:cloud_firestore/cloud_firestore.dart';

import 'room_role.dart';

enum SeatState { open, locked, occupied, reserved, disabled }

class SeatModel {
  final int seatNumber;

  final SeatState state;

  final String? userId;
  final String? userName;
  final String? photo;

  final RoomRole role;

  final bool micOn;

  final bool isSpeaking;

  final bool mutedByAdmin;

  final bool invited;

  final Timestamp? joinedAt;

  const SeatModel({
    required this.seatNumber,
    required this.state,
    this.userId,
    this.userName,
    this.photo,
    this.role = RoomRole.listener,
    this.micOn = true,
    this.isSpeaking = false,
    this.mutedByAdmin = false,
    this.invited = false,
    this.joinedAt,
  });

  bool get isOccupied => state == SeatState.occupied;

  bool get isLocked => state == SeatState.locked;

  bool get isOpen => state == SeatState.open;

  bool get isReserved => state == SeatState.reserved;

  bool get isDisabled => state == SeatState.disabled;

  bool get hasUser => userId != null && userId!.isNotEmpty;

  factory SeatModel.fromMap(Map<String, dynamic> json) {
    return SeatModel(
      seatNumber: json['seatNumber'] ?? 0,
      state: _stateFromString(json['state']),
      userId: json['userId'],
      userName: json['userName'],
      photo: json['photo'],
      role: RoomRoleX.fromString(json['role']),
      micOn: json['micOn'] ?? true,
      isSpeaking: json['isSpeaking'] ?? false,
      mutedByAdmin: json['mutedByAdmin'] ?? false,
      invited: json['invited'] ?? false,
      joinedAt: json['joinedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "seatNumber": seatNumber,
      "state": state.name,
      "userId": userId,
      "userName": userName,
      "photo": photo,
      "role": role.value,
      "micOn": micOn,
      "isSpeaking": isSpeaking,
      "mutedByAdmin": mutedByAdmin,
      "invited": invited,
      "joinedAt": joinedAt,
    };
  }

  SeatModel copyWith({
    int? seatNumber,
    SeatState? state,
    String? userId,
    String? userName,
    String? photo,
    RoomRole? role,
    bool? micOn,
    bool? isSpeaking,
    bool? mutedByAdmin,
    bool? invited,
    Timestamp? joinedAt,
  }) {
    return SeatModel(
      seatNumber: seatNumber ?? this.seatNumber,
      state: state ?? this.state,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      photo: photo ?? this.photo,
      role: role ?? this.role,
      micOn: micOn ?? this.micOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      mutedByAdmin: mutedByAdmin ?? this.mutedByAdmin,
      invited: invited ?? this.invited,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  static SeatState _stateFromString(dynamic value) {
    switch (value) {
      case "locked":
        return SeatState.locked;

      case "occupied":
        return SeatState.occupied;

      case "reserved":
        return SeatState.reserved;

      case "disabled":
        return SeatState.disabled;

      default:
        return SeatState.open;
    }
  }
}
