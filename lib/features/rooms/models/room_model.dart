class RoomModel {
  final String id;
  final String title;
  final String createdBy;
  final int usersCount;
  final DateTime createdAt;

  final bool isPrivate;
  final String? password;

  /// live | stage | gaming
  final String roomType;

  /// Owner of room
  final String hostId;

  /// 4 / 8 / 12
  final int maxSeats;

  final bool chatEnabled;
  final bool lobbyEnabled;

  const RoomModel({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.usersCount,
    required this.createdAt,
    required this.isPrivate,
    this.password,
    required this.roomType,
    required this.hostId,
    required this.maxSeats,
    required this.chatEnabled,
    required this.lobbyEnabled,
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
      hostId: data['hostId'] ?? '',
      maxSeats: data['maxSeats'] ?? 8,
      chatEnabled: data['chatEnabled'] ?? true,
      lobbyEnabled: data['lobbyEnabled'] ?? true,
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
      'hostId': hostId,
      'maxSeats': maxSeats,
      'chatEnabled': chatEnabled,
      'lobbyEnabled': lobbyEnabled,
    };
  }

  RoomModel copyWith({
    String? id,
    String? title,
    String? createdBy,
    int? usersCount,
    DateTime? createdAt,
    bool? isPrivate,
    String? password,
    String? roomType,
    String? hostId,
    int? maxSeats,
    bool? chatEnabled,
    bool? lobbyEnabled,
  }) {
    return RoomModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      usersCount: usersCount ?? this.usersCount,
      createdAt: createdAt ?? this.createdAt,
      isPrivate: isPrivate ?? this.isPrivate,
      password: password ?? this.password,
      roomType: roomType ?? this.roomType,
      hostId: hostId ?? this.hostId,
      maxSeats: maxSeats ?? this.maxSeats,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      lobbyEnabled: lobbyEnabled ?? this.lobbyEnabled,
    );
  }
}
