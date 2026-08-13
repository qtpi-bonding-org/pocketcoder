import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill.freezed.dart';
part 'skill.g.dart';

/// A Goose "skill" — a markdown file Goose loads on demand. Unlike other
/// domain models in this app, this is NOT PocketBase-backed: there is no
/// `id`, no `fromRecord`. Every instance is built from JSON returned by the
/// skills API routes (services/pocketbase/internal/api/skills.go), which
/// proxy Goose's own _goose/unstable/sources/* responses. `path` is the
/// stable identifier Goose uses for update/delete — see
/// docs/superpowers/specs/2026-07-23-skills-ui-design.md.
@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String name,
    required String description,
    required String content,
    required String path,
    required bool global,
    @Default(false) bool system,
  }) = _Skill;

  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);
}
