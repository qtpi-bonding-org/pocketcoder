import 'package:flutter_error_privserver/flutter_error_privserver.dart';

/// Version context attached to a diagnostic report, best-effort -- any
/// field can be null if it couldn't be read (offline, unauthenticated,
/// platform channel failure), never blocking the report itself.
class DiagnosticEnvironment {
  const DiagnosticEnvironment({
    this.appVersion,
    this.serverVersion,
    this.nixosVersion,
  });

  final String? appVersion;
  final String? serverVersion;
  final String? nixosVersion;
}

/// Formats only the allowlisted fields from Privserver's ErrorEntry.
class DiagnosticReportFormatter {
  DiagnosticReportFormatter._();

  static String format(
    ErrorEntry entry, {
    DiagnosticEnvironment environment = const DiagnosticEnvironment(),
  }) {
    final lines = <String>[
      'PocketCoder diagnostic report',
      if (environment.appVersion case final version?) 'App version: $version',
      if (environment.serverVersion case final version?)
        'PocketBase version: $version',
      if (environment.nixosVersion case final version?)
        'NixOS version: $version',
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

  static String formatMany(
    Iterable<ErrorBoxEntry> entries, {
    DiagnosticEnvironment environment = const DiagnosticEnvironment(),
  }) {
    return entries
        .map((entry) => format(entry.errorData, environment: environment))
        .join('\n\n');
  }
}
