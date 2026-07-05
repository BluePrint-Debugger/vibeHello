class MemberModel {
  final String uid;
  final String name;
  final String photo;
  final String role;
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
      role: map['role'] ?? 'listener',
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
      'role': role,
      'seatNumber': seatNumber,
      'micOn': micOn,
      'isSpeaking': isSpeaking,
      'mutedByAdmin': mutedByAdmin,
      'chatBlocked': chatBlocked,
      'joinedAt': joinedAt,
    };
  }
}
