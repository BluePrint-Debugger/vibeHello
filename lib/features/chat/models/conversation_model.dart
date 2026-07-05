class ConversationModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime updatedAt;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory ConversationModel.fromMap(String id, Map<String, dynamic> data) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }
}
