import 'package:intl/intl.dart';

class DateTimeUtils {
  DateTimeUtils._();

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }

    return _formatDate(date);
  }

  static String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy · HH:mm').format(date);
  }

  static String formatTimestamp(dynamic timestamp) {
    if (timestamp is String) return timestamp;
    if (timestamp is DateTime) return formatRelative(timestamp);
    return '';
  }
}