class RoomEventModel {
  final String type;
  final String userId;
  final String userName;
  final DateTime createdAt;

  const RoomEventModel({
    required this.type,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  factory RoomEventModel.fromMap(Map<String, dynamic> map) {
    return RoomEventModel(
      type: map['type'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt,
    };
  }
}
