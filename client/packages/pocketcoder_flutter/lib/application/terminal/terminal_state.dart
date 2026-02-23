import 'package:freezed_annotation/freezed_annotation.dart';

part 'terminal_state.freezed.dart';

enum TerminalStatus {
  initial,
  syncingKeys,
  connecting,
  connected,
  error,
}

@freezed
class SshTerminalState with _$SshTerminalState {
  const factory SshTerminalState({
    @Default(TerminalStatus.initial) TerminalStatus status,
    String? error,
    String? sessionId,
  }) = _SshTerminalState;

  const SshTerminalState._();

  bool get isConnecting => status == TerminalStatus.connecting;
  bool get isConnected => status == TerminalStatus.connected;
  bool get isSyncingKeys => status == TerminalStatus.syncingKeys;
  bool get hasError => status == TerminalStatus.error;
}
