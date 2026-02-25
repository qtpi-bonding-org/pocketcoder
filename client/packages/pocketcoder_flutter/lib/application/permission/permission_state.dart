import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/permission.dart';

part 'permission_state.freezed.dart';

@freezed
class PermissionState with _$PermissionState {
  const factory PermissionState.initial() = _Initial;
  const factory PermissionState.loading() = _Loading;
  const factory PermissionState.loaded(List<Permission> requests) =
      _Loaded;
  const factory PermissionState.error(String message) = _Error;
}
