import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_provider.freezed.dart';
part 'harness_provider.g.dart';

@freezed
abstract class HarnessProvider with _$HarnessProvider {
  const factory HarnessProvider({
    required String id,
    required String harness,
    required String provider,
    bool? supportsOauth,
    String? oauthAuthenticator,
    String? apiKeyEnvOverride,
    bool? isPinned,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessProvider;

  factory HarnessProvider.fromRecord(RecordModel record) =>
      HarnessProvider.fromJson(record.toJson());

  factory HarnessProvider.fromJson(Map<String, dynamic> json) =>
      _$HarnessProviderFromJson(json);
}
