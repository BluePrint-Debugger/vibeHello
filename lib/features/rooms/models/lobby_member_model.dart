class LobbyMemberModel {
  final String uid;
  final String name;
  final String photo;
  final DateTime joinedAt;
  final int requestedSeat;

  const LobbyMemberModel({
    required this.uid,
    required this.name,
    required this.photo,
    required this.joinedAt,
    required this.requestedSeat,
  });

  factory LobbyMemberModel.fromMap(Map<String, dynamic> map) {
    return LobbyMemberModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      photo: map['photo'] ?? '',
      requestedSeat: map['requestedSeat'] ?? -1,
      joinedAt: map['joinedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photo': photo,
      'requestedSeat': requestedSeat,
      'joinedAt': joinedAt,
    };
  }
}
