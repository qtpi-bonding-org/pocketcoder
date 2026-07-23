import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'goose_session.freezed.dart';
part 'goose_session.g.dart';

@freezed
abstract class GooseSession with _$GooseSession {
  const factory GooseSession({
    required String id,
    required String chat,
    required String user,
    required String gooseSessionId,
    String? gooseVersion,
    String? provider,
  }) = _GooseSession;

  factory GooseSession.fromRecord(RecordModel record) =>
      GooseSession.fromJson(record.toJson());

  factory GooseSession.fromJson(Map<String, dynamic> json) =>
      _$GooseSessionFromJson(json);
}
