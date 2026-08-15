class ReportModel {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final String? details;
  final String context; // e.g. "room:<roomId>", "chat:<chatId>"
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    this.details,
    required this.context,
    required this.createdAt,
  });

  factory ReportModel.fromMap(String id, Map<String, dynamic> data) {
    return ReportModel(
      id: id,
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      reason: data['reason'] ?? '',
      details: data['details'],
      context: data['context'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'details': details,
      'context': context,
      'createdAt': createdAt,
    };
  }
}

/// Standard reasons — Play Store reviewers expect a defined reason list,
/// not just a free-text box.
const List<String> kReportReasons = [
  'Harassment or bullying',
  'Hate speech or discrimination',
  'Nudity or sexual content',
  'Spam or scam',
  'Violence or dangerous behavior',
  'Underage user',
  'Other',
];
