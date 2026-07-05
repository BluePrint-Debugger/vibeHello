class ChatMessageModel {
  final String id;
  final String text;
  final String senderName;
  final String senderId;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.senderName,
    required this.senderId,
    required this.createdAt,
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessageModel(
      id: id,
      text: data['text'] ?? '',
      senderName: data['senderName'] ?? '',
      senderId: data['senderId'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
    );
  }
}
