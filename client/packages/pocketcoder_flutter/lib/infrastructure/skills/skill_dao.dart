import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class SkillDao extends BaseDao<Skill> {
  SkillDao(PocketBase pb) : super(pb, Collections.skills, Skill.fromJson);
}
