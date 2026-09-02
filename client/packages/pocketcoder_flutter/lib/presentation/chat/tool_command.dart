import 'dart:convert';

/// `args`' raw JSON shape is harness-defined, not ACP-standardized; invalid
/// or still-streaming JSON is tolerated, not an error.
String commandFor({
  required String name,
  required String args,
  required String? toolKind,
  required String fallback,
}) {
  if (toolKind == 'execute' && args.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(args);
      if (decoded is Map) {
        for (final key in const ['command', 'cmd', 'script']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
    } catch (_) {}
  }
  if (name.trim().isNotEmpty) {
    return args.trim().isEmpty ? name : '$name $args';
  }
  return fallback;
}
