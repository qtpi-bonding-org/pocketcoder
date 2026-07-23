import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_auth.freezed.dart';
part 'harness_auth.g.dart';

@freezed
abstract class HarnessAuth with _$HarnessAuth {
  const factory HarnessAuth({
    required String id,
    required String user,
    required String harness,
    @JsonKey(unknownEnumValue: HarnessAuthAuthType.unknown) required HarnessAuthAuthType authType,
    @JsonKey(unknownEnumValue: HarnessAuthStatus.unknown) required HarnessAuthStatus status,
    String? authUrl,
    DateTime? expiresAt,
  }) = _HarnessAuth;

  factory HarnessAuth.fromRecord(RecordModel record) =>
      HarnessAuth.fromJson(record.toJson());

  factory HarnessAuth.fromJson(Map<String, dynamic> json) =>
      _$HarnessAuthFromJson(json);
}

enum HarnessAuthAuthType {
  @JsonValue('api_key')
  api_key,
  @JsonValue('oauth')
  oauth,
  @JsonValue('__unknown__')
  unknown,
}

enum HarnessAuthStatus {
  @JsonValue('unauthenticated')
  unauthenticated,
  @JsonValue('pending')
  pending,
  @JsonValue('authenticated')
  authenticated,
  @JsonValue('expired')
  expired,
  @JsonValue('__unknown__')
  unknown,
}
