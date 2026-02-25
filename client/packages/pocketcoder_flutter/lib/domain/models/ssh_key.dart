import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'ssh_key.freezed.dart';
part 'ssh_key.g.dart';

@freezed
class SshKey with _$SshKey {
  const factory SshKey({
    required String id,
    String? user,
    required String publicKey,
    String? deviceName,
    required String fingerprint,
    String? algorithm,
    double? keySize,
    String? comment,
    DateTime? expiresAt,
    DateTime? lastUsed,
    bool? isActive,
    DateTime? created,
    DateTime? updated,
  }) = _SshKey;

  factory SshKey.fromRecord(RecordModel record) =>
      SshKey.fromJson(record.toJson());

  factory SshKey.fromJson(Map<String, dynamic> json) =>
      _$SshKeyFromJson(json);
}
