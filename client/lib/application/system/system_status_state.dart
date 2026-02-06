import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_status_state.freezed.dart';

@freezed
class SystemStatusState with _$SystemStatusState {
  const factory SystemStatusState({
    @Default(true) bool isConnected,
  }) = _SystemStatusState;

  factory SystemStatusState.initial() => const SystemStatusState();
}
