import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'provider_api_key.freezed.dart';
part 'provider_api_key.g.dart';

@freezed
abstract class ProviderApiKey with _$ProviderApiKey {
  const factory ProviderApiKey({
    required String id,
    required String owner,
    required String provider,
    required String apiKey,
    String? baseUrl,
    dynamic extraEnv,
    DateTime? lastVerified,
    DateTime? created,
    DateTime? updated,
  }) = _ProviderApiKey;

  factory ProviderApiKey.fromRecord(RecordModel record) =>
      ProviderApiKey.fromJson(record.toJson());

  factory ProviderApiKey.fromJson(Map<String, dynamic> json) =>
      _$ProviderApiKeyFromJson(json);
}
