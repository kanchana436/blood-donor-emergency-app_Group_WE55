import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
  }

  static String formatDateOnly(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  static String formatTimeOnly(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}
