import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'skill.freezed.dart';
part 'skill.g.dart';

@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String id,
    String? user,
    bool? isSystem,
    required String name,
    required String description,
    required String content,
    dynamic metadata,
    bool? active,
  }) = _Skill;

  factory Skill.fromRecord(RecordModel record) =>
      Skill.fromJson(record.toJson());

  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);
}
