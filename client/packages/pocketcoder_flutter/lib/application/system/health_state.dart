import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/system/system_health.dart';

part 'health_state.freezed.dart';

@freezed
class HealthState with _$HealthState {
  const factory HealthState({
    @Default([]) List<SystemHealth> checks,
    @Default(false) bool isLoading,
    String? error,
  }) = _HealthState;
}
