import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'sandbox_agent.freezed.dart';
part 'sandbox_agent.g.dart';

@freezed
class SandboxAgent with _$SandboxAgent {
  const factory SandboxAgent({
    required String id,
    required String sandboxAgentId,
    required String delegatingAgentId,
    double? tmuxWindowId,
    String? chat,
    String? delegatingAgent,
  }) = _SandboxAgent;

  factory SandboxAgent.fromRecord(RecordModel record) =>
      SandboxAgent.fromJson(record.toJson());

  factory SandboxAgent.fromJson(Map<String, dynamic> json) =>
      _$SandboxAgentFromJson(json);
}
