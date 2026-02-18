import 'package:freezed_annotation/freezed_annotation.dart';

part 'status_state.freezed.dart';

@freezed
class StatusState with _$StatusState {
  const factory StatusState({
    @Default(true) bool isConnected,
  }) = _StatusState;

  factory StatusState.initial() => const StatusState();
}
