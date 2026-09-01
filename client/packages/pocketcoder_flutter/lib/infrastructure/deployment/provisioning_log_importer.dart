import 'dart:convert';

import 'provisioning_log_db.dart';

/// Invalid records are skipped, not fatal -- one malformed journal line
/// should not discard the rest of the bounded provisioning window.
Future<void> importProvisioningJournal({
  required ProvisioningLogDb db,
  required String instanceId,
  required String output,
}) async {
  for (final line in const LineSplitter().convert(output)) {
    if (line.trim().isEmpty) continue;
    try {
      final json = jsonDecode(line);
      if (json is! Map<String, dynamic>) continue;
      final timestamp = int.tryParse('${json['__REALTIME_TIMESTAMP'] ?? ''}');
      final cursor = json['__CURSOR']?.toString();
      final message = json['MESSAGE']?.toString();
      if (timestamp == null || cursor == null || message == null) continue;
      await db.upsertEntry(
        instanceId: instanceId,
        source: _sourceFor(json),
        timestampMicros: timestamp,
        journalCursor: cursor,
        level: _levelFor(json),
        message: message,
      );
    } on FormatException {
      // Journal output is bounded but not trusted to be perfect.
    }
  }
}

String _sourceFor(Map<String, dynamic> json) {
  final identifier = (json['SYSLOG_IDENTIFIER'] ?? '').toString();
  final container = (json['CONTAINER_NAME'] ?? '').toString();
  if (container.isNotEmpty || identifier.startsWith('docker')) {
    return 'docker';
  }
  if (identifier == 'pocketcoder-installer') {
    return 'bootscript';
  }
  if (identifier == 'pocketcoder-bootstrap' ||
      identifier.startsWith('pocketcoder-')) {
    return 'nixos';
  }
  return 'nixos';
}

String _levelFor(Map<String, dynamic> json) {
  final priority = int.tryParse('${json['PRIORITY'] ?? ''}');
  return switch (priority) {
    0 || 1 || 2 || 3 => 'error',
    4 => 'warning',
    5 || 6 => 'info',
    _ => 'debug',
  };
}
