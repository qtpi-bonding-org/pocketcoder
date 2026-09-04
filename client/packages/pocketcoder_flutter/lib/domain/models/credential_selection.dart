import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'credential_selection.freezed.dart';
part 'credential_selection.g.dart';

@freezed
abstract class CredentialSelection with _$CredentialSelection {
  const factory CredentialSelection({
    required String id,
    required String user,
    required String harness,
    required String provider,
    @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
    required CredentialSelectionMode mode,
    String? oauthAccount,
    DateTime? created,
    DateTime? updated,
  }) = _CredentialSelection;

  factory CredentialSelection.fromRecord(RecordModel record) =>
      CredentialSelection.fromJson(record.toJson());

  factory CredentialSelection.fromJson(Map<String, dynamic> json) =>
      _$CredentialSelectionFromJson(json);
}

enum CredentialSelectionMode {
  @JsonValue('oauth')
  oauth,
  @JsonValue('api_key')
  apiKey,
  @JsonValue('none')
  none,
  @JsonValue('__unknown__')
  unknown,
}
