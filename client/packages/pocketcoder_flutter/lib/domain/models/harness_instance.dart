import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_instance.freezed.dart';
part 'harness_instance.g.dart';

@freezed
abstract class HarnessInstance with _$HarnessInstance {
  const factory HarnessInstance({
    required String id,
    required String harness,
    String? user,
    String? harnessModel,
    String? oauthAccount,
    String? launchKey,
    required String containerName,
    String? acpEndpoint,
    String? secret,
    @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown) required HarnessInstanceStatus status,
    String? lastError,
    bool? managed,
    bool? retryable,
    String? lastUsed,
    String? lastLogExcerpt,
    dynamic syncedCredentials,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessInstance;

  factory HarnessInstance.fromRecord(RecordModel record) =>
      HarnessInstance.fromJson(record.toJson());

  factory HarnessInstance.fromJson(Map<String, dynamic> json) =>
      _$HarnessInstanceFromJson(json);
}

enum HarnessInstanceStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('running')
  running,
  @JsonValue('stopped')
  stopped,
  @JsonValue('error')
  error,
  @JsonValue('__unknown__')
  unknown,
}
