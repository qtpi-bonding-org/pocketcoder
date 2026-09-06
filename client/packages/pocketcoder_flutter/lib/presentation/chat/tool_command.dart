import 'dart:convert';

import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

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

/// Maps a harness-supplied permission option kind to an action kind.
///
/// The harness can suggest `reject_*` or `allow_*` kinds, which map to
/// refusal and primary respectively. No harness-supplied kind can ever be
/// destructive, which requires app-level semantics the harness cannot possess.
ActionKind actionKindForPermissionOption(String harnessOptionKind) =>
    harnessOptionKind.startsWith('reject')
        ? ActionKind.refusal
        : ActionKind.primary;
