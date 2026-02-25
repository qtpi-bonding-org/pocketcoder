import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_api_models.freezed.dart';
part 'permission_api_models.g.dart';

@freezed
class PermissionResponse with _$PermissionResponse {
  const factory PermissionResponse({
    required bool permitted,
    required String id,
    required String status,
  }) = _PermissionResponse;

  factory PermissionResponse.fromJson(Map<String, dynamic> json) =>
      _$PermissionResponseFromJson(json);
}
