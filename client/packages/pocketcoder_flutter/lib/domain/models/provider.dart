import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'provider.freezed.dart';
part 'provider.g.dart';

@freezed
abstract class Provider with _$Provider {
  const factory Provider({
    required String id,
    required String providerId,
    required String name,
    String? apiKeyEnv,
    dynamic apiKeyEnvs,
    String? baseUrlEnv,
    DateTime? syncedAt,
  }) = _Provider;

  factory Provider.fromRecord(RecordModel record) =>
      Provider.fromJson(record.toJson());

  factory Provider.fromJson(Map<String, dynamic> json) =>
      _$ProviderFromJson(json);
}
