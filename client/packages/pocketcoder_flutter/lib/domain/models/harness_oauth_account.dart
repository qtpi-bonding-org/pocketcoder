import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_oauth_account.freezed.dart';
part 'harness_oauth_account.g.dart';

@freezed
abstract class HarnessOauthAccount with _$HarnessOauthAccount {
  const factory HarnessOauthAccount({
    required String id,
    required String harness,
    required String provider,
    required String owner,
    required String name,
    @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown) required HarnessOauthAccountVisibility visibility,
    @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown) required HarnessOauthAccountStatus status,
    String? lastError,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessOauthAccount;

  factory HarnessOauthAccount.fromRecord(RecordModel record) =>
      HarnessOauthAccount.fromJson(record.toJson());

  factory HarnessOauthAccount.fromJson(Map<String, dynamic> json) =>
      _$HarnessOauthAccountFromJson(json);
}

enum HarnessOauthAccountVisibility {
  @JsonValue('personal')
  personal,
  @JsonValue('deployment')
  deployment,
  @JsonValue('__unknown__')
  unknown,
}

enum HarnessOauthAccountStatus {
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('connecting')
  connecting,
  @JsonValue('connected')
  connected,
  @JsonValue('error')
  error,
  @JsonValue('__unknown__')
  unknown,
}
