import 'package:flutter_error_privserver/flutter_error_privserver.dart';

/// Formats only the allowlisted fields from Privserver's ErrorEntry.
class DiagnosticReportFormatter {
  DiagnosticReportFormatter._();

  static String format(ErrorEntry entry) {
    final lines = <String>[
      'PocketCoder diagnostic report',
      'Timestamp: ${entry.timestamp.toIso8601String()}',
      'Source: ${entry.source}',
      'Exception type: ${entry.errorType}',
      'Error code: ${entry.errorCode}',
    ];
    final userMessage = entry.userMessage;
    if (userMessage != null && userMessage.isNotEmpty) {
      lines.add('Message: $userMessage');
    }
    lines
      ..add('Stack trace:')
      ..add(entry.stackTrace);
    return lines.join('\n');
  }

  static String formatMany(Iterable<ErrorBoxEntry> entries) {
    return entries.map((entry) => format(entry.errorData)).join('\n\n');
  }
}
