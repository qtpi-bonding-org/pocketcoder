import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_auth_attempt.freezed.dart';
part 'harness_auth_attempt.g.dart';

@freezed
abstract class HarnessAuthAttempt with _$HarnessAuthAttempt {
  const factory HarnessAuthAttempt({
    required String id,
    required String account,
    required String provider,
    @JsonKey(unknownEnumValue: HarnessAuthAttemptStatus.unknown) required HarnessAuthAttemptStatus status,
    String? lastError,
    DateTime? expiresAt,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessAuthAttempt;

  factory HarnessAuthAttempt.fromRecord(RecordModel record) =>
      HarnessAuthAttempt.fromJson(record.toJson());

  factory HarnessAuthAttempt.fromJson(Map<String, dynamic> json) =>
      _$HarnessAuthAttemptFromJson(json);
}

enum HarnessAuthAttemptStatus {
  @JsonValue('starting')
  starting,
  @JsonValue('awaiting_input')
  awaitingInput,
  @JsonValue('succeeded')
  succeeded,
  @JsonValue('failed')
  failed,
  @JsonValue('expired')
  expired,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('__unknown__')
  unknown,
}
