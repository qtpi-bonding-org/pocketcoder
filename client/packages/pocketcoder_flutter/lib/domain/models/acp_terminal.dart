import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'acp_terminal.freezed.dart';
part 'acp_terminal.g.dart';

@freezed
class AcpTerminal with _$AcpTerminal {
  const factory AcpTerminal({
    required String id,
    required String acpTerminalId,
    required String acpSessionId,
    String? name,
    String? cwd,
    double? exitCode,
    @JsonKey(unknownEnumValue: AcpTerminalStatus.unknown) required AcpTerminalStatus status,
    String? chat,
    double? tmuxWindowId,
  }) = _AcpTerminal;

  factory AcpTerminal.fromRecord(RecordModel record) =>
      AcpTerminal.fromJson(record.toJson());

  factory AcpTerminal.fromJson(Map<String, dynamic> json) =>
      _$AcpTerminalFromJson(json);
}

enum AcpTerminalStatus {
  @JsonValue('running')
  running,
  @JsonValue('exited')
  exited,
  @JsonValue('killed')
  killed,
  @JsonValue('__unknown__')
  unknown,
}
