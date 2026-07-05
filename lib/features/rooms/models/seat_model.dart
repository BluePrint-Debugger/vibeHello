import 'package:cloud_firestore/cloud_firestore.dart';

enum SeatState { open, locked, occupied, reserved }

class SeatModel {
  final int seatNumber;

  final SeatState state;

  final String? userId;
  final String? userName;
  final String? photo;

  final bool micOn;
  final bool isSpeaking;

  final String role;

  final Timestamp? joinedAt;

  const SeatModel({
    required this.seatNumber,
    required this.state,
    this.userId,
    this.userName,
    this.photo,
    this.micOn = true,
    this.isSpeaking = false,
    this.role = "listener",
    this.joinedAt,
  });

  factory SeatModel.fromMap(Map<String, dynamic> json) {
    return SeatModel(
      seatNumber: json['seatNumber'] ?? 0,
      state: _stateFromString(json['state']),
      userId: json['userId'],
      userName: json['userName'],
      photo: json['photo'],
      micOn: json['micOn'] ?? true,
      isSpeaking: json['isSpeaking'] ?? false,
      role: json['role'] ?? "listener",
      joinedAt: json['joinedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seatNumber': seatNumber,
      'state': state.name,
      'userId': userId,
      'userName': userName,
      'photo': photo,
      'micOn': micOn,
      'isSpeaking': isSpeaking,
      'role': role,
      'joinedAt': joinedAt,
    };
  }

  static SeatState _stateFromString(dynamic value) {
    switch (value) {
      case 'locked':
        return SeatState.locked;
      case 'occupied':
        return SeatState.occupied;
      case 'reserved':
        return SeatState.reserved;
      default:
        return SeatState.open;
    }
  }

  SeatModel copyWith({
    int? seatNumber,
    SeatState? state,
    String? userId,
    String? userName,
    String? photo,
    bool? micOn,
    bool? isSpeaking,
    String? role,
    Timestamp? joinedAt,
  }) {
    return SeatModel(
      seatNumber: seatNumber ?? this.seatNumber,
      state: state ?? this.state,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      photo: photo ?? this.photo,
      micOn: micOn ?? this.micOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
