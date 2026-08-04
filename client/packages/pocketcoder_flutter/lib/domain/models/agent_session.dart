import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'agent_session.freezed.dart';
part 'agent_session.g.dart';

@freezed
abstract class AgentSession with _$AgentSession {
  const factory AgentSession({
    required String id,
    required String chat,
    required String user,
    required String acpSessionId,
    String? gooseVersion,
    String? provider,
    String? harnessInstance,
  }) = _AgentSession;

  factory AgentSession.fromRecord(RecordModel record) =>
      AgentSession.fromJson(record.toJson());

  factory AgentSession.fromJson(Map<String, dynamic> json) =>
      _$AgentSessionFromJson(json);
}
