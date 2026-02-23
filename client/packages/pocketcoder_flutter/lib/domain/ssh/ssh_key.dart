import 'package:freezed_annotation/freezed_annotation.dart';

part 'ssh_key.freezed.dart';
part 'ssh_key.g.dart';

@freezed
class SshKey with _$SshKey {
  const factory SshKey({
    required String id,
    required String user,
    required String publicKey,
    String? deviceName,
    required String fingerprint,
    String? algorithm,
    int? keySize,
    String? comment,
    DateTime? expiresAt,
    DateTime? lastUsed,
    @Default(true) bool isActive,
    DateTime? created,
    DateTime? updated,
  }) = _SshKey;

  factory SshKey.fromJson(Map<String, dynamic> json) => _$SshKeyFromJson(json);
}
