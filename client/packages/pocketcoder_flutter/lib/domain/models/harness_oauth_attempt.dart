import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_oauth_attempt.freezed.dart';
part 'harness_oauth_attempt.g.dart';

@freezed
abstract class HarnessOauthAttempt with _$HarnessOauthAttempt {
  const factory HarnessOauthAttempt({
    required String id,
    required String account,
    @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
    required HarnessOauthAttemptStatus status,
    String? lastError,
    DateTime? expiresAt,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessOauthAttempt;

  factory HarnessOauthAttempt.fromRecord(RecordModel record) =>
      HarnessOauthAttempt.fromJson(record.toJson());

  factory HarnessOauthAttempt.fromJson(Map<String, dynamic> json) =>
      _$HarnessOauthAttemptFromJson(json);
}

enum HarnessOauthAttemptStatus {
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
