import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'provider_key.freezed.dart';
part 'provider_key.g.dart';

@freezed
abstract class ProviderKey with _$ProviderKey {
  const factory ProviderKey({
    required String id,
    required String user,
    required String provider,
    dynamic envVars,
  }) = _ProviderKey;

  factory ProviderKey.fromRecord(RecordModel record) =>
      ProviderKey.fromJson(record.toJson());

  factory ProviderKey.fromJson(Map<String, dynamic> json) =>
      _$ProviderKeyFromJson(json);
}
