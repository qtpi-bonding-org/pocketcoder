import 'package:pocketbase/pocketbase.dart';

import 'subagent.dart';

abstract class ISubagentRepository {
  Future<List<Subagent>> getSubagents();
  Future<Subagent?> getSubagent(String subagentId);
  Stream<List<RecordModel>> watchSubagents();
}