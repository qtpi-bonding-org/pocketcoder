import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/permission/permission_request.dart';

part 'permission_state.freezed.dart';

@freezed
class PermissionState with _$PermissionState {
  const factory PermissionState.initial() = _Initial;
  const factory PermissionState.loading() = _Loading;
  const factory PermissionState.loaded(List<PermissionRequest> requests) =
      _Loaded;
  const factory PermissionState.error(String message) = _Error;
}
