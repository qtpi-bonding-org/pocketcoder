import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_account.freezed.dart';
part 'harness_account.g.dart';

@freezed
abstract class HarnessAccount with _$HarnessAccount {
  const factory HarnessAccount({
    required String id,
    required String harness,
    required String owner,
    required String name,
    @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown) required HarnessAccountVisibility visibility,
    @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown) required HarnessAccountCredentialMode credentialMode,
    String? providerKey,
    @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown) required HarnessAccountStatus status,
    String? lastError,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessAccount;

  factory HarnessAccount.fromRecord(RecordModel record) =>
      HarnessAccount.fromJson(record.toJson());

  factory HarnessAccount.fromJson(Map<String, dynamic> json) =>
      _$HarnessAccountFromJson(json);
}

enum HarnessAccountVisibility {
  @JsonValue('personal')
  personal,
  @JsonValue('deployment')
  deployment,
  @JsonValue('__unknown__')
  unknown,
}

enum HarnessAccountCredentialMode {
  @JsonValue('account')
  account,
  @JsonValue('api_key')
  api_key,
  @JsonValue('none')
  none,
  @JsonValue('__unknown__')
  unknown,
}

enum HarnessAccountStatus {
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('connecting')
  connecting,
  @JsonValue('connected')
  connected,
  @JsonValue('error')
  error,
  @JsonValue('needs_api_key')
  needs_api_key,
  @JsonValue('__unknown__')
  unknown,
}
