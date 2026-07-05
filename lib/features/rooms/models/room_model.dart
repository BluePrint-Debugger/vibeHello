class RoomModel {
  final String id;
  final String title;
  final String createdBy;
  final int usersCount;
  final DateTime createdAt;
  final bool isPrivate;
  final String? password;
  final String roomType;

  RoomModel({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.usersCount,
    required this.createdAt,
    required this.isPrivate,
    this.password,
    required this.roomType,
  });

  factory RoomModel.fromMap(String id, Map<String, dynamic> data) {
    return RoomModel(
      id: id,
      title: data['title'] ?? '',
      createdBy: data['createdBy'] ?? '',
      usersCount: data['usersCount'] ?? 0,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      isPrivate: data['isPrivate'] ?? false,
      password: data['password'],
      roomType: data['roomType'] ?? 'live',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdBy': createdBy,
      'usersCount': usersCount,
      'createdAt': createdAt,
      'isPrivate': isPrivate,
      'password': password,
      'roomType': roomType,
    };
  }
}
