import 'package:freezed_annotation/freezed_annotation.dart';

part 'ssh_key.freezed.dart';
part 'ssh_key.g.dart';

@freezed
class SshKey with _$SshKey {
  const factory SshKey({
    required String id,
    @JsonKey(name: 'user') required String userId,
    @JsonKey(name: 'public_key') required String publicKey,
    @JsonKey(name: 'device_name') String? deviceName,
    String? fingerprint,
    @JsonKey(name: 'last_used') DateTime? lastUsed,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    DateTime? created,
    DateTime? updated,
  }) = _SshKey;

  factory SshKey.fromJson(Map<String, dynamic> json) => _$SshKeyFromJson(json);
}
