// Regression test for a real class of bug: an exception type reaching
// UiFlowListener's fallback with no AppExceptionKeyMapper entry renders as
// Dart's default Object.toString() (e.g. "Instance of
// 'ProviderReauthenticationRequired'") or, for a DomainException subtype,
// as its raw internal detail (e.g. "ObservabilityException: failed to
// fetch traces") -- both violate this project's "technical detail stays
// in logs, user messages are generic + localized" rule. Already fixed
// once for AgentActionFailure (see agent_actions_api.dart); this covers
// the remaining unmapped types found in the E2E audit.
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/agent/provider_reauthentication_required.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/feedback/exception_mapper.dart';

void main() {
  final mapper = AppExceptionKeyMapper();

  test(
      'maps ProviderReauthenticationRequired to its dedicated, already-'
      'localized key instead of falling through to null', () {
    final key = mapper.map(const ProviderReauthenticationRequired());
    expect(key, isNotNull);
    expect(key!.key, 'provider.reauthentication.required');
  });

  test(
      'maps every previously-unmapped DomainException subtype to a safe '
      'generic key, not null', () {
    final errors = <Object>[
      RepositoryException('boom'),
      McpException('boom'),
      ObservabilityException('boom'),
      SkillsException('boom'),
      SchedulerException('boom'),
      FilesException('boom'),
    ];
    for (final error in errors) {
      final key = mapper.map(error);
      expect(key, isNotNull, reason: '${error.runtimeType} should be mapped');
      expect(key!.key, MessageKey.genericError.key,
          reason: '${error.runtimeType} should fall back to the generic '
              'error key, not leak its raw message');
    }
  });
}
