// The one hand-authored ACP protocol DTO in the agent stack (plan Task 9,
// spec §6.2): `acp_dart` ships no elicitation response type, so this is the
// single deliberate exception to "protocol types are never hand-mirrored."
// Guarded by the up-parity test (agent_actions_parity_test.dart) so a future
// acp_dart release that adds this type is the trigger to delete this file
// and switch over.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'elicitation_response.freezed.dart';

/// The user's response to a pending ACP elicitation (a side-channel form
/// request distinct from permission — see the backend's
/// `Bridge.ElicitationPending`). Mirrors ACP's `action` discriminator:
/// `accept` (with the filled-in form `content`), `decline`, or `cancel`.
@freezed
class ElicitationResponse with _$ElicitationResponse {
  const factory ElicitationResponse.accept(Map<String, dynamic> content) =
      ElicitationResponseAccept;
  const factory ElicitationResponse.decline() = ElicitationResponseDecline;
  const factory ElicitationResponse.cancel() = ElicitationResponseCancel;

  const ElicitationResponse._();

  /// The `{action, content?}` body `session/elicitation/{id}` expects
  /// (c1's `internal/api/agent.go` binds `action` + `content`, plan Task 4).
  Map<String, dynamic> toJson() => when(
        accept: (content) => {'action': 'accept', 'content': content},
        decline: () => {'action': 'decline'},
        cancel: () => {'action': 'cancel'},
      );
}
