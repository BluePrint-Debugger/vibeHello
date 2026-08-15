import 'room_role.dart';

class MemberModel {
  final String uid;
  final String name;
  final String photo;

  final RoomRole role;

  final int seatNumber;

  final bool micOn;

  final bool isSpeaking;

  final bool mutedByAdmin;

  final bool chatBlocked;

  final DateTime joinedAt;

  const MemberModel({
    required this.uid,
    required this.name,
    required this.photo,
    required this.role,
    required this.seatNumber,
    required this.micOn,
    required this.isSpeaking,
    required this.mutedByAdmin,
    required this.chatBlocked,
    required this.joinedAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      photo: map['photo'] ?? '',
      role: RoomRoleX.fromString(map['role']),
      seatNumber: map['seatNumber'] ?? -1,
      micOn: map['micOn'] ?? false,
      isSpeaking: map['isSpeaking'] ?? false,
      mutedByAdmin: map['mutedByAdmin'] ?? false,
      chatBlocked: map['chatBlocked'] ?? false,
      joinedAt: map['joinedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photo': photo,
      'role': role.value,
      'seatNumber': seatNumber,
      'micOn': micOn,
      'isSpeaking': isSpeaking,
      'mutedByAdmin': mutedByAdmin,
      'chatBlocked': chatBlocked,
      'joinedAt': joinedAt,
    };
  }

  MemberModel copyWith({
    String? uid,
    String? name,
    String? photo,
    RoomRole? role,
    int? seatNumber,
    bool? micOn,
    bool? isSpeaking,
    bool? mutedByAdmin,
    bool? chatBlocked,
    DateTime? joinedAt,
  }) {
    return MemberModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      photo: photo ?? this.photo,
      role: role ?? this.role,
      seatNumber: seatNumber ?? this.seatNumber,
      micOn: micOn ?? this.micOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      mutedByAdmin: mutedByAdmin ?? this.mutedByAdmin,
      chatBlocked: chatBlocked ?? this.chatBlocked,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
