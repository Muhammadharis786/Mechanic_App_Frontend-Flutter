import 'package:flutter/material.dart';

class TimeAgo {
  /// Formats a UTC ISO-8601 string into a relative time string (e.g. "5min ago")
  static String format(dynamic timestamp) {
    if (timestamp == null || timestamp.toString().isEmpty) {
      return 'just now';
    }

    try {
      final String dateStr = timestamp.toString();
      // Backend may send Z or not, parse safely
      DateTime utcDate = DateTime.parse(dateStr);
      
      // Ensure it's treated as UTC if it doesn't have the Z suffix
      if (!utcDate.isUtc && !dateStr.endsWith('Z')) {
         utcDate = DateTime.utc(
          utcDate.year, utcDate.month, utcDate.day,
          utcDate.hour, utcDate.minute, utcDate.second,
          utcDate.millisecond, utcDate.microsecond
        );
      }
      
      final DateTime localDate = utcDate.toLocal();
      final DateTime now = DateTime.now();
      final Duration diff = now.difference(localDate);

      if (diff.inSeconds < 60) {
        return 'just now';
      }
      
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}min ago';
      }
      
      if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      }
      
      if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      }
      
      if (diff.inDays < 365) {
        int weeks = (diff.inDays / 7).floor();
        return '${weeks}w ago';
      }
      
      int years = (diff.inDays / 365).floor();
      return '${years}y ago';
    } catch (e) {
      debugPrint('❌ TimeAgo Error: $e for timestamp: $timestamp');
      return 'just now';
    }
  }
}
